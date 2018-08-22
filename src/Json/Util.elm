module Json.Util exposing (exact)

import Json.Decode as Decode exposing (Decoder)


{-| A decoder that only succeeds when it decodes to the given value.
-}
exact : Decoder String -> String -> Decoder String
exact decoder x =
    Decode.andThen
        (\y ->
            if x == y then
                Decode.succeed x

            else
                Decode.fail ("expected " ++ x ++ " got " ++ y)
        )
        decoder
