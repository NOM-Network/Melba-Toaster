# API schema

This document outlines the API schema of communication between backend and Toaster.

## Communication

- Backend - server
- Toaster - client

We are using Websockets with JSON messages (except binary audio), default port is 9876.

## Schema

## Client -> server

### Ready for speech

JSON message, tells server that the Toaster is ready to receive a new audio message (initializing or finished speaking + timeout). Doesn't require asknowledgment.

```json
    {
        "type": "ReadyForSpeech"
    }
```

## Server -> client

### Send audio

Binary message, MP3 file sent as is. `NewSpeech` message must be sent after the succesful transfer. Client should send `ReadyForSpeech` beforehand.

### New speech

JSON message, contains the initial prompt and the response from LLM. Must be send after `Send Audio`.

```json
    {
        "type": "NewSpeech",
        "prompt": "<prompt_text>",
        "text": "<response_text>"
    }
```

### Play Animation

JSON message, contains the name of animation needs to be applied to the Live2D model

> TODO: Finalize the set of animations.

```json
    {
        "type": "PlayAnimation",
        "animationName": "<animation_name>",
    }
```

### Set Toggle

JSON message, contains the name of the toggle needs to be applied to the Live2D model, and its desired state.

> TODO: Finalize the set of toggles.

```json
    {
        "type": "SetTogle",
        "toggleName": "<toggle_name>",
        "enabled": "<bool>"
    }
```
