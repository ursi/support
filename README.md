# SupPort

SupPort is a simple framework for Elm ports. The JavaScript component is available [here](https://github.com/ursi/support-js).

### Goals
* Reduce redundancy
* Improve readability
* Make using ports feel as close as possible to sending messages with values, as one does in Elm
* Catch/prevent typos, as communication is string-based


With that said, let's look at some code! The following is the port component of some code that will control audio elements. It will be used to play/pause audio, as well as keep the model up to date with the current time of each audio element.

```elm
port module Audio exposing
    ( Msg(..)
    , in_
    , pause
    , play
    )

import Json.Decode as D
import Json.Encode as E exposing (Value)
import SupPort


type Msg
    = Error D.Error
    | TimeReceived String Float


play : String -> Cmd msg
play id =
    out "Play" [ E.string id ]


pause : String -> Cmd msg
pause id =
    out "Pause" [ E.string id ]


-- the two arguments here correspond to the method name and the method arguments in the JS code
-- seen in the example JS code below
out : String -> List Value -> Cmd msg
out =
    SupPort.out audioOut


in_ : (Msg -> msg) -> Sub msg
in_ =
    SupPort.in_
        audioIn
        Error
        [ ( "TimeReceived"
          , D.map2 TimeReceived
                (D.field "id" D.string)
                (D.field "time" D.float)
          )
        ]


port audioOut : Value -> Cmd msg


port audioIn : (Value -> msg) -> Sub msg
```

Note the names of the ports. Naming your ports the same name followed by either `Out` or `In` is required so that the part of the name that is shared is all that's needed to identify both ports on the JavaScript side. If your port module only needs one port of the pair, it is okay to only define one of them, but the appropriate suffix is still required.

The corresponding JavaScript to handle this is:

```js
import SupPort from '@ursi/support'

const app = Elm.Main.init();

const port = SupPort(app.ports);

port(`audio`, {
    Play(id) {
        const audio = document.getElementById(id);
        audio.play();

        // When a function is returned, the function takes 1 argument, which itself is a function
        // of 2 arguments. The 2 arguments correspond to the appropriate value in the
        // List ( String, Decoder Msg ) passed into SupPort.in_ in the Elm code above.
        return send => {
            const i = setInterval(() => {
                if (audio.paused)
                    clearInterval(i);
                else
                    send(`TimeReceived`, {id, time: audio.currentTime});
            }, 100);
        }
    },

    Pause(id) {
        const audio = document.getElementById(id);
        audio.pause();

        // When a tuple of [string, value] is returned, it corresponds to the appropriate value
        // in the List ( String, Decoder Msg ) passed into SupPort.in_ in the Elm code above.
        return [`TimeReceived`, {id, time: audio.currentTime}];
    }
});
```

Finally, to subscribe to values sent into Elm, we import our `Audio` module, and use `Audio.in_`

```elm
module Main exposing(..)

import Json.Decode as D
import Audio


type Msg
    = TimeReceived String Float
    | PortError D.Error


subscriptions : Model -> Sub Msg
subscriptions _ =
    Audio.in_
        (\msg ->
            case msg of
                Audio.TimeReceived id time ->
                    TimeReceived id time

                Audio.Error error ->
                    PortError error
        )
```

And you're done! Since we've mapped each message to a custom type, the compiler will make sure we cover all our incoming messages, including the mandatory error message. If you've misspelled a message on either side, you'll get an helpful runtime error letting you know.

Special thanks to Murphy Randle for his talk [The Importance of Ports](https://www.youtube.com/watch?v=P3pL85n9_5s) which inspired the creation of this package.
