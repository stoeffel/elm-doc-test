module VerifyExamples.Compiler exposing (compile)

import VerifyExamples.Ast exposing (..)
import Regex exposing (HowMany(..), regex)
import String
import String.Extra


compile : String -> List TestSuite -> String
compile moduleName suites =
    let
        filteredSuites =
            List.filter (.tests >> List.isEmpty >> not) suites
    in
    String.join "\n" <|
        List.concat
            [ moduleHeader moduleName <| List.concatMap .imports suites
            , spec moduleName filteredSuites
            ]


moduleHeader : String -> List String -> List String
moduleHeader moduleName imports =
    [ "module Doc." ++ moduleName ++ "Spec exposing (spec)"
    , ""
    , "import Test"
    , "import Expect"
    , "import " ++ moduleName ++ " exposing(..)"
    ]
        ++ imports


spec : String -> List TestSuite -> List String
spec moduleName suites =
    let
        renderedSuites =
            List.indexedMap toDescribe suites
                |> List.concat
    in
    [ ""
    , ""
    , "spec : Test.Test"
    , "spec ="
    , indent 1 "Test.describe \"" ++ escape moduleName ++ "\" <|"
    ]
        ++ List.map (indent 2) renderedSuites
        ++ [ indent 1 "]" ]


toDescribe : Int -> TestSuite -> List String
toDescribe index suite =
    let
        renderedTests =
            List.indexedMap toTest suite.tests
                |> List.concat
    in
    (startOfListOrNot index
        ++ "Test.describe \""
        ++ (suite.functionToTest
                |> Maybe.map ((++) "#")
                |> Maybe.withDefault ("Comment: " ++ toString (index + 1))
                |> escape
           )
        ++ "\" <|"
    )
        :: List.map (indent 1) (toLetIns suite.helperFunctions)
        ++ List.map (indent 1) renderedTests
        ++ [ indent 1 "]" ]


toTest : Int -> Test -> List String
toTest index test =
    [ indent 0
        (startOfListOrNot index
            ++ "Test.test \""
            ++ "Example: "
            ++ toString (index + 1)
            ++ " -- "
            ++ exampleName test
            ++ "\" <|"
        )
    , indent 1 "\\() ->"
    , indent 2 "Expect.equal"
    , indent 3 "("
    ]
        ++ (List.map (indent 4) <| String.lines test.assertion)
        ++ [ indent 3 ")"
           , indent 3 "("
           ]
        ++ (List.map (indent 4) <| String.lines test.expectation)
        ++ [ indent 3 ")"
           ]


exampleName : Test -> String
exampleName test =
    (test.assertion ++ " --> " ++ test.expectation)
        |> String.Extra.replace "\n" " "
        |> String.Extra.clean
        |> String.Extra.ellipsis 40
        |> String.Extra.surround "`"
        |> escape


toLetIns : List Function -> List String
toLetIns fns =
    case List.filter .isUsed fns of
        [] ->
            []

        _ ->
            indent 0 "let"
                :: List.concatMap (List.map (indent 1) << String.lines << .value) fns
                ++ [ indent 0 "in"
                   ]


startOfListOrNot : Int -> String
startOfListOrNot index =
    if index == 0 then
        "[ "
    else
        ", "


indent : Int -> String -> String
indent count str =
    List.repeat (count * 4) " "
        ++ [ str ]
        |> String.join ""


escape : String -> String
escape =
    Regex.replace All (regex "\\\\") (\_ -> "\\\\")
        >> Regex.replace All (regex "\\\"") (\_ -> "\\\"")
        >> Regex.replace All (regex "\\s\\s+") (\_ -> " ")
