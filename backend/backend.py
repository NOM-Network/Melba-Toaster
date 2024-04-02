import asyncio
import websockets
import json
import random
import msgpack


async def hello(websocket):
    backwards = True

    async for message in websocket:
        data = json.loads(message)

        if data["type"] == "ReadyForSpeech":
            print(">> Ready for speech")

            filename = "chunks/twister_{}.ogg"
            prompt = [
                "Hey, Melba! Tell us a tongue twister",
                "Hey, Melba! Tell us a tongue twister but backwards",
            ]
            response = [
                ["Oi, mates.", 1],
                ["You wanna hear a tongue twister?", 2],
                [
                    "Melba's toaster toast toasticular toast that taste as tasty toasty.",
                    3,
                ],
                ["Peace out! Try saying that three times fast.", 4],
            ]

            backwards = not backwards
            if backwards:
                response.reverse()

            chunks = len(response)
            for i in range(chunks):
                if i == 0:
                    type = "NewSpeech"
                else:
                    type = "ContinueSpeech"

                current_chunk = response[i]
                with open(filename.format(current_chunk[1]), mode="rb") as f:
                    message = {
                        "type": type,
                        "prompt": prompt[backwards],
                        "response": current_chunk[0],
                        "emotions": [
                            random_emotion(),
                            random_emotion(),
                            random_emotion(),
                        ],
                        "audio": f.read(),
                    }
                await websocket.send(msgpack.packb(message, use_bin_type=True))

                await asyncio.sleep(random.uniform(1.0, 2.0))

            message = {"type": "EndSpeech", "prompt": prompt[backwards]}
            await websocket.send(msgpack.packb(message, use_bin_type=True))

        elif data["type"] == "DoneSpeaking":
            print(">>> Done Speaking")

        else:
            print(">>> Unknown message")
            await websocket.send("hi")


async def main():
    print("Ready!")

    async with websockets.serve(hello, "", 9876):
        await asyncio.Future()  # run forever


def random_emotion():
    return random.choice(
        [
            "admiration",
            "amusement",
            "anger",
            "annoyance",
            "approval",
            "caring",
            "confusion",
            "curiosity",
            "desire",
            "disappointment",
            "disapproval",
            "disgust",
            "embarrassment",
            "excitement",
            "fear",
            "gratitude",
            "grief",
            "joy",
            "love",
            "nervousness",
            "optimism",
            "pride",
            "realization",
            "relief",
            "remorse",
            "sadness",
            "surprise",
            "neutral",
            "anticipation",
        ]
    )


if __name__ == "__main__":
    asyncio.run(main())
