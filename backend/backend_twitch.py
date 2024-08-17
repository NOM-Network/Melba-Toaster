import asyncio
import websockets
import random
import os
import dotenv
import msgpack
import json

dotenv.load_dotenv()

test_username = os.getenv("TEST_USERNAME")

CONNECTIONS = set()


async def backend_server(websocket):
    print("--- New client!")
    try:
        CONNECTIONS.add(websocket)

        async for message in websocket:
            data = json.loads(message)
            if data["type"] == "ReadyForSpeech":
                print(">> Ready for speech")
            elif data["type"] == "DoneSpeaking":
                print(">> Done speaking")
            else:
                print(">> Unknown message: ", data)
    finally:
        CONNECTIONS.discard(websocket)


async def message_all(message):
    websockets.broadcast(CONNECTIONS, message)


async def twitch_client():
    async with websockets.connect("ws://irc-ws.chat.twitch.tv:80") as websocket:
        await websocket.send("CAP REQ")
        await websocket.send(f"PASS justinfan{random.randint(0, 1000000)}")
        await websocket.send(f"NICK justinfan{random.randint(0, 1000000)}")
        await websocket.send(f"JOIN #{os.getenv('CHANNEL_NAME', 'melbathetoast')}")
        print("--- Twitch connected!")

        async for message in websocket:
            if message.startswith("PING"):
                await websocket.send("PONG :tmi.twitch.tv")
            else:
                await twitch_handler(message)


async def twitch_handler(message):
    if f"PRIVMSG #{test_username} :!toaster" not in message:
        return

    message = message.rsplit(" :!toaster", 1)[-1]
    message = {
        "type": "Command",
        "command": message[1:].replace("\r\n", ""),
    }
    print(f"---- Sending {message}")
    await message_all(msgpack.packb(message, use_bin_type=True))


if __name__ == "__main__":
    start_server = websockets.serve(backend_server, "", 9876)

    print("Starting server...")
    asyncio.get_event_loop().run_until_complete(start_server)

    print("Starting client...")
    asyncio.ensure_future(twitch_client())

    asyncio.get_event_loop().run_forever()
