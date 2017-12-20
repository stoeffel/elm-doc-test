module VerifyExamples.Comment exposing (Comment(..), parse)

import Regex exposing (HowMany(..), Regex)


type Comment
    = FunctionDoc { functionName : String, comment : String }
    | ModuleDoc String


parse : String -> List Comment
parse =
    Regex.find All commentRegex
        >> List.filterMap (toComment << .submatches)


toComment : List (Maybe String) -> Maybe Comment
toComment matches =
    case matches of
        (Just comment) :: _ :: Nothing :: _ ->
            Just (ModuleDoc comment)

        (Just comment) :: _ :: (Just functionName) :: _ ->
            Just (FunctionDoc { functionName = functionName, comment = comment })

        _ ->
            Nothing


commentRegex : Regex
commentRegex =
    Regex.regex <|
        String.concat
            [ "({-[^]*?-})" -- anything between comments
            , newline
            , "("
            , "([^\\s(" ++ newline ++ ")]+)" -- anything that is not a space or newline
            , "\\s[:=]" -- until ` :` or ` =`
            , ")?" -- it's possible that we have examples in comment not attached to a function
            ]


newline : String
newline =
    "\x0D?\n"
