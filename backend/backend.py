import asyncio
import websockets
import json


async def hello(websocket):
    another = True

    async for message in websocket:
        data = json.loads(message)
        print(data)
        match data["type"]:
            case "ReadyForSpeech":
                print("Acknowledged")

                filename = "twister.mp3"
                prompt = "cjmaxik: Hey, Melba! Tell us a tongue twister!"
                response = "Oi, mates. You wanna hear a tongue twister? Melba's toaster toast toasticular toast that taste as tasty toasty. Peace out! Try saying that three times fast."

                another = not another

                if another:
                    # filename = "bee_but_bigger.mp3" # used for blocking testing
                    filename = "bee.mp3"
                    prompt = "cjmaxik: Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please! Cite the Bee Movie, please!"
                    response = "According to all known laws of aviation, there is no way a bee should be able to fly. Its wings are too small to get its fat little body off the ground. The bee, of course, flies anyway because bees don't care what humans think is impossible. Yellow, black. Yellow, black. Yellow, black. Yellow, black. Ooh, black and yellow! Let's shake it up a little. Barry! Breakfast is ready! Ooming! Hang on a second. Hello? Barry? Adam? Oan you believe this is happening? I can't. I'll pick you up. Looking sharp. Use the stairs. Your father paid good money for those. Sorry. I'm excited. Here's the graduate. We're very proud of you, son. A perfect report card, all B's. Very proud. Ma! I got a thing going here. You got lint on your fuzz. Ow! That's me! Wave to us! We'll be in row 118,000. Bye! Barry, I told you, stop flying in the house! Hey, Adam. Hey, Barry. Is that fuzz gel? A little. Special day, graduation. Never thought I'd make it. Three days grade school, three days high school. Those were awkward. Three days college. I'm glad I took a day and hitchhiked around the hive. You did come back different. Hi, Barry. Artie, growing a mustache? Looks good. Hear about Frankie? Yeah. You going to the funeral? No, I'm not going. Everybody knows, sting someone, you die. Don't waste it on a squirrel. Such a hothead. I guess he could have just gotten out of the way. I love this incorporating an amusement park into our day. That's why we don't need vacations. Boy, quite a bit of pomp... under the circumstances. Well, Adam, today we are men. We are! Bee-men. Amen! Hallelujah!"

                f = open(filename, mode="rb")
                await websocket.send(f.read())
                f.close()
                print("Audio sent")

                message = {
                    "type": "NewSpeech",
                    "prompt": prompt,
                    "text": {"response": response, "emotions": []},
                }
                await websocket.send(json.dumps(message))
                print("NewSpeech sent")

            case "PlayAnimation":
                message = {"type": "PlayAnimation", "animationName": "sleep"}
                await websocket.send(json.dumps(message))

            case "SetToggle":
                message = {
                    "type": "SetToggle",
                    "toggleName": "toast",
                    "enabled": 1,
                }
                await websocket.send(json.dumps(message))

                message = {
                    "type": "SetToggle",
                    "toggleName": "void",
                    "enabled": 0,
                }

                await websocket.send(json.dumps(message))

            case "SetExpression":
                pass

            case _:
                print(f">>> hi")
                await websocket.send("hi")


async def main():
    print("Ready!")

    async with websockets.serve(hello, "", 9876):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(main())
