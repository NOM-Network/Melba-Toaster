# API schema

This document outlines the API schema of communication between backend and Toaster.

## Communication

- Backend - server
- Toaster - client

We are using Websockets as a transport layer, all the data is wrapped into [MessagePack](https://msgpack.org/) binary messages.

Default port is 9876.

## Schema

## Client -> server

### Done speaking

Tells server that the Toaster is done speaking, although doesn't ready for a new message yet. Doesn't require asknowledgment.

```json
    {
        "type": "DoneSpeaking"
    }
```

### Ready for speech

Tells server that the Toaster is ready to receive a new message. Doesn't require asknowledgment.

```json
    {
        "type": "ReadyForSpeech"
    }
```

## Server -> client

### New speech

Contains the initial prompt and the first response chuck from LLM (including audio in OGG format). Possible `emotions` are listed [here](https://huggingface.co/SamLowe/roberta-base-go_emotions/blob/main/config.json#L14).

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

Contains the subsequence responses from LLM (including audio in OGG format). Must include the initial prompt for tracking purposes.

```json
    {
        "type": "ContinueSpeech",
        "prompt": "<prompt_text>",
        "response": "<response_text>",
        "emotions": ["<array_of_emotions>"],
        "audio": "<binary data>"
    }
```

### End speech

Signals the end of the response from LLM. Must include the initial prompt for tracking purposes.

```json
    {
        "type": "EndSpeech",
        "prompt": "<prompt_text>"
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

### Send Command

Contains the command from Twitch chat

```json
    {
        "type": "Command",
        "command": "<command>"
    }
```
