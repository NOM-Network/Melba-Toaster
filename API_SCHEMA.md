# API schema

This document outlines the API schema of communication between backend and Toaster.

## Communication

- Backend - server
- Toaster - client

We are using Websockets as a transport layer, all the data is wrapped into [MessagePack](https://msgpack.org/) binary messages.

Default port is 9876.

## Schema

## Client -> server

### Ready for speech

Tells server that the Toaster is ready to receive a new audio message. Doesn't require asknowledgment.

```json
    {
        "type": "ReadyForSpeech"
    }
```

## Server -> client

### New speech

Contains the initial prompt and the first response chuck from LLM (including audio).

```json
    {
        "type": "NewSpeech",
        "prompt": "<prompt_text>",
        "response": "<response_text>",
        "emotions": ["<array_of_emotions>"],
        "audio": "<binary data>"
    }
```

### Continue speech

Contains the subsequence responses from LLM (including audio).

```json
    {
        "type": "ContinueSpeech",
        "response": "<response_text>",
        "audio": "<binary data>"
    }
```

### End speech

Contains the last response chunk from LLM (including audio).

```json
    {
        "type": "EndSpeech",
        "response": "<response_text>",
        "audio": "<binary data>"
    }
```

### Play Animation

Contains the name of animation needs to be applied to the Live2D model

```json
    {
        "type": "PlayAnimation",
        "animationName": "<animation_name>",
    }
```

### Set Toggle

Contains the name of the toggle needs to be applied to the Live2D model, and its desired state.

```json
    {
        "type": "SetTogle",
        "toggleName": "<toggle_name>",
        "enabled": "<bool>"
    }
```
