module VerifyExamples.Compiler exposing (compile)

import Regex exposing (HowMany(..), regex)
import String
import String.Extra
import String.Util exposing (escape, indent, unlines)
import VerifyExamples.Function exposing (Function)
import VerifyExamples.Test exposing (Test)
import VerifyExamples.TestSuite exposing (TestSuite)


type alias Info =
    { imports : List String
    , types : List String
    , functionToTest : Maybe String
    , helperFunctions : List Function
    , moduleName : String
    , testName : String
    }


compile : String -> TestSuite -> List ( String, String )
compile moduleName suite =
    let
        info =
            { imports = suite.imports
            , types = suite.types
            , functionToTest = suite.functionToTest
            , helperFunctions = suite.helperFunctions
            , moduleName = moduleName
            , testName = moduleName
            }
    in
    if List.length suite.types > 0 then
        suite.tests
            |> List.indexedMap
                (\index ->
                    compileTestPerFunction
                        { info
                            | testName = testName moduleName suite.functionToTest index
                        }
                        index
                )
    else
        [ ( moduleName
          , List.concat
                [ moduleHeader info
                , suite.tests
                    |> List.indexedMap (compileTest info)
                    |> List.concat
                ]
                |> unlines
          )
        ]


testName : String -> Maybe String -> Int -> String
testName moduleName functionToTest index =
    moduleName
        ++ ".Function_"
        ++ Maybe.withDefault "" functionToTest
        ++ "_Example"
        ++ toString index


compileTestPerFunction : Info -> Int -> Test -> ( String, String )
compileTestPerFunction info index test =
    ( info.testName
    , unlines <|
        List.concat
            [ moduleHeader info
            , info.types
            , [ "" ]
            , info.helperFunctions
                |> List.filter .isUsed
                |> List.map .value
            , [ "" ]
            , spec info test index
            ]
    )


compileTest : Info -> Int -> Test -> List String
compileTest info index test =
    spec info test index


moduleHeader : Info -> List String
moduleHeader { moduleName, testName, imports } =
    [ "module Doc." ++ testName ++ "Spec exposing (..)"
    , ""
    , "-- This file got generated by [elm-verify-examples](https://github.com/stoeffel/elm-verify-examples)."
    , "-- Please don't modify this file by hand!"
    , ""
    , "import Test"
    , "import Expect"
    , "import " ++ moduleName ++ " exposing(..)"
    , ""
    ]
        ++ imports
        ++ [ "" ]


spec : Info -> Test -> Int -> List String
spec { testName } test index =
    [ ""
    , ""
    , "spec" ++ toString index ++ " : Test.Test"
    , "spec" ++ toString index ++ " ="
    , indent 1
        ("Test.test \""
            ++ "Example: "
            ++ testName
            ++ " -- "
            ++ exampleName test
            ++ "\" <|"
        )
    , indent 2 "\\() ->"
    , indent 3 "Expect.equal"
    , indent 4 "("
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
