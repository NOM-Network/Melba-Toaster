# Mock backend

This folder contains the mock backend for the Toaster project. It comes in two flavors:

- `backend.py` just loops through two sound files with prompt/response over and over for testing basic functionality.
- `backend_twitch.py` connects to the Twitch chat for testing chat commands.

Communication with the backend follows [this API schema](API_SCHEMA.md).

## How to use

1. Install [Python 3.11+](https://www.python.org/downloads/)
2. *(optional)* Create a virtual environment and activate it
3. Execute this command to install deps:

    ```bash
    pip install -r reqs.txt
    ```

4. *(for `backend_twitch.py`)* Duplicate `.env.example`, rename it to `.env` and change `CHANNEL_NAME` and `TEST_USERNAME` variables.

    > *The backend will only acknowledge messages from those channel and username.*

5. Run one of the following commands to start the backend:

    ```bash
    python backend.py
    ```

    ```bash
    python backend_twitch.py
    ```
