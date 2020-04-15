module SupPort exposing (out, in_)

{-| See the README for instructions on how to use these two functions.

@docs out, in_

-}

import Dict exposing (Dict)
import Json.Decode as D exposing (Decoder, Value, decodeValue)
import Json.Encode as E


{-| -}
out : (Value -> Cmd msg) -> String -> Value -> Cmd msg
out outPort =
    \msgName value ->
        outPort <|
            E.object
                [ ( "msg", E.string msgName )
                , ( "data", value )
                ]


{-| -}
in_ :
    ((Value -> msg) -> Sub msg)
    -> (D.Error -> portMsg)
    -> List ( String, Decoder portMsg )
    -> (portMsg -> msg)
    -> Sub msg
in_ inPort error msgDataToMsgList msgDataToMsg =
    let
        msgDataToMsgDict =
            Dict.fromList msgDataToMsgList
    in
    inPort <|
        \msgData ->
            msgDataToMsg <|
                case decodeValue (decodeMsg msgDataToMsgDict) msgData of
                    Ok msgName ->
                        let
                            decoder =
                                Dict.get msgName msgDataToMsgDict
                                    |> Maybe.withDefault (D.fail "something has gone wrong :(")
                        in
                        case decodeValue (D.field "data" decoder) msgData of
                            Ok value ->
                                value

                            Err decoderError ->
                                error decoderError

                    Err decoderError ->
                        error decoderError


decodeMsg : Dict String (Decoder portMsg) -> Decoder String
decodeMsg msgDataToMsgDict =
    D.field "msg" D.string
        |> D.andThen
            (\msg ->
                if Dict.member msg msgDataToMsgDict then
                    D.succeed msg

                else
                    D.fail <| "'" ++ msg ++ "'" ++ " is not a valid message."
            )
