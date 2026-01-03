import os
import multiprocessing
import threading
import dbt.adapters.base
import subprocess


# Patch multiprocessing for Lambda environment where /dev/shm is missing
def patch_multiprocessing():
    import multiprocessing.synchronize

    class MockRLock:
        def __init__(self, *args, **kwargs):
            self._lock = threading.RLock()

        def __enter__(self):
            return self._lock.__enter__()

        def __exit__(self, *args):
            return self._lock.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._lock.acquire(*args, **kwargs)

        def release(self):
            return self._lock.release()

        def _is_owned(self):
            return True

    class MockLock:
        def __init__(self, *args, **kwargs):
            self._lock = threading.Lock()

        def __enter__(self):
            return self._lock.__enter__()

        def __exit__(self, *args):
            return self._lock.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._lock.acquire(*args, **kwargs)

        def release(self):
            return self._lock.release()

    class MockSemaphore:
        def __init__(self, value=1, *args, **kwargs):
            self._sem = threading.Semaphore(value)

        def __enter__(self):
            return self._sem.__enter__()

        def __exit__(self, *args):
            return self._sem.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._sem.acquire(*args, **kwargs)

        def release(self):
            return self._sem.release()

    class MockBoundedSemaphore:
        def __init__(self, value=1, *args, **kwargs):
            self._sem = threading.BoundedSemaphore(value)

        def __enter__(self):
            return self._sem.__enter__()

        def __exit__(self, *args):
            return self._sem.__exit__(*args)

        def acquire(self, *args, **kwargs):
            return self._sem.acquire(*args, **kwargs)

        def release(self):
            return self._sem.release()

    multiprocessing.synchronize.RLock = MockRLock
    multiprocessing.synchronize.Lock = MockLock
    multiprocessing.synchronize.Semaphore = MockSemaphore
    multiprocessing.synchronize.BoundedSemaphore = MockBoundedSemaphore


patch_multiprocessing()

# Shim for Credentials import error in newer dbt versions
try:
    from dbt.adapters.base import Credentials
except ImportError:
    try:
        from dbt.adapters.contracts.connection import Credentials

        dbt.adapters.base.Credentials = Credentials
    except ImportError:
        pass

from dbt.cli.main import dbtRunner, dbtRunnerResult

# Ensure writable directories exist
os.makedirs("/tmp/logs", exist_ok=True)
os.makedirs("/tmp/target", exist_ok=True)
os.makedirs("/tmp/target-base", exist_ok=True)

# Set environment variables for dbt to use /tmp
os.environ["DBT_LOG_PATH"] = "/tmp/logs"
os.environ["DBT_TARGET_PATH"] = "/tmp/target"
os.environ["DBT_PROFILES_DIR"] = "."
os.environ["DBT_USER_CONFIG_DIR"] = "/tmp"

# initialize
dbt = dbtRunner()

# create CLI args as a list of strings
default_args = [
    "--target",
    "dev",
    "--log-path",
    "/tmp/logs",
    "--target-path",
    "/tmp/target",
    "--target",
    os.getenv("ENVIRONMENT", "dev"),
    "--profiles-dir",
    ".",
]


def restore_target_from_s3():
    """
    Download the previous dbt target state from S3 for comparison.
    Stores in /tmp/target-base to allow state comparison after new run.
    """
    dbt_state_bucket = os.getenv("DBT_STATE_BUCKET")
    environment = os.getenv("ENVIRONMENT", "dev")

    if not dbt_state_bucket:
        print("INFO: DBT_STATE_BUCKET not set. Starting with clean state.")
        return

    try:
        # Create S3 path with environment prefix
        s3_path = f"s3://{dbt_state_bucket}/{environment}/target/"

        print(f"Restoring previous dbt state from {s3_path}")

        # Use subprocess to run aws s3 sync (download from S3)
        result = subprocess.run(
            [
                "aws",
                "s3",
                "sync",
                s3_path,
                "/tmp/target-base",
                "--quiet",  # Reduce output
            ],
            capture_output=True,
            text=True,
            check=False,  # Don't raise exception on non-zero exit
        )

        if result.returncode == 0:
            print(f"✓ Successfully restored previous state to /tmp/target-base")
        else:
            # It's OK if state doesn't exist yet (first run)
            print(f"INFO: No previous state found in S3 (first run or empty bucket)")
    except Exception as e:
        print(f"INFO: Failed to restore state from S3: {str(e)}")


def sync_target_to_s3():
    """
    Sync the dbt target directory to S3 bucket for state persistence.
    Uses AWS CLI to upload manifest, artifacts, and logs for future runs.
    """
    dbt_state_bucket = os.getenv("DBT_STATE_BUCKET")
    environment = os.getenv("ENVIRONMENT", "dev")

    if not dbt_state_bucket:
        print("WARNING: DBT_STATE_BUCKET not set. Skipping state sync.")
        return

    try:
        # Create S3 path with environment prefix
        s3_path = f"s3://{dbt_state_bucket}/{environment}/target/"

        print(f"Syncing dbt target to {s3_path}")

        # Use subprocess to run aws s3 sync
        result = subprocess.run(
            [
                "aws",
                "s3",
                "sync",
                "/tmp/target",
                s3_path,
                "--delete",  # Remove files in S3 that are not in local
                "--quiet",  # Reduce output
            ],
            capture_output=True,
            text=True,
            check=False,  # Don't raise exception on non-zero exit
        )

        if result.returncode == 0:
            print(f"✓ Successfully synced dbt target to {s3_path}")
        else:
            print("WARNING: Failed to sync target to S3")
            print(f"stdout: {result.stdout}")
            print(f"stderr: {result.stderr}")
    except Exception as e:
        print(f"ERROR: Failed to sync target to S3: {str(e)}")


def handler(event, context):
    """
    AWS Lambda handler to run dbt commands.
    1. Parses event for dbt command and CLI args.
    2. Invokes dbt with specified command and args.
    3. Syncs dbt target directory to S3 for state persistence.
    4. Returns success or failure response.
    5. Logs output to /tmp/logs and /tmp/target.
    6. Raises exception on failure.
    7. Default command is 'build' with selection of 'my_second_dbt_model

    Event example::
    {
        "command": ["build"],
        "cli_args": ["--select", "+my_second_dbt_model"]
    }

    Another example:
    {
        "command": ["run"],
        "cli_args": ["--select", "my_dbt_model"]
    }

    """
    print("Event:", event)
    print("Context:", context)

    # Restore previous state from S3 for comparison
    # restore_target_from_s3()

    # Prepare CLI arguments
    command = event.get("command", ["build"])
    cli_args = event.get("cli_args", ["--select", "+my_second_dbt_model"])

    print(f"Running dbt {' '.join(command)} {' '.join(cli_args)}")

    # Run dbt build command
    res: dbtRunnerResult = dbt.invoke(command + default_args + cli_args)

    if res.success:
        print("✓ DBT build succeeded")
        # Sync target directory to S3 after successful dbt execution
        print("Uploading state to S3...")
        # sync_target_to_s3()
    else:
        print("✗ DBT build failed")
        raise Exception("DBT build failed")

    return {"statusCode": 200 if res.success else 500, "body": "DBT build completed"}


if __name__ == "__main__":
    # For local testing
    test_event = {
        "command": ["build"],
        "cli_args": ["--select", "+my_second_dbt_model"],
    }
    test_context = {}
    handler(test_event, test_context)
