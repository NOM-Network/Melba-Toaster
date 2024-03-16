import asyncio
import websockets
import json
import random
import msgpack


async def hello(websocket):
    another = True

    async for message in websocket:
        data = json.loads(message)
        print(data)

        match data["type"]:
            case "ReadyForSpeech":
                print("Acknowledged")

                filename = "chunks/twister_{}.ogg"
                prompt1 = "Hey, Melba! Tell us a tongue twister"
                prompt2 = prompt1 + " but backwards"
                response = [
                    ["Oi, mates.", 1],
                    ["You wanna hear a tongue twister?", 2],
                    [
                        "Melba's toaster toast toasticular toast that taste as tasty toasty.",
                        3,
                    ],
                    ["Peace out! Try saying that three times fast.", 4],
                ]

                another = not another
                if another:
                    response.reverse()

                chunks = len(response)
                print("-- Sending the message {} times".format(chunks))

                for i in range(chunks):
                    if i == 0:
                        type = "NewSpeech"
                    else:
                        type = "ContinueSpeech"

                    current_chunk = response[i]
                    f = open(filename.format(current_chunk[1]), mode="rb")
                    message = {
                        "type": type,
                        "prompt": prompt2 if another else prompt1,
                        "response": current_chunk[0],
                        "emotions": [
                            random_emotion(),
                            random_emotion(),
                            random_emotion(),
                        ],
                        "audio": f.read(),
                    }
                    f.close()

                    print(message["response"])

                    time_to_sleep = random.uniform(1.0, 2.0)
                    await websocket.send(msgpack.packb(message, use_bin_type=True))

                    print(
                        "--- {} sent, {} left, sleeping for {} seconds...".format(
                            type, chunks - i - 1, time_to_sleep
                        )
                    )
                    if i != chunks:
                        await asyncio.sleep(time_to_sleep)

                message = {
                    "type": "EndSpeech",
                    "prompt": prompt2 if another else prompt1,
                }
                await websocket.send(msgpack.packb(message, use_bin_type=True))

            case _:
                print(f">>> hi")
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
