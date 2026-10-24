module DomainTest exposing (suite)

import Domain
import Expect
import Json.Decode as D
import Json.Encode as E
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Caderno local"
        [ test "contagem ignora espaços e pontuação isolada, preserva números e palavras acentuadas" <|
            \_ ->
                Expect.equal [ 0, 0, 4, 3, 3 ] (List.map Domain.wordCount [ "", "… — !", "Uma xícara, 2 histórias.", "uma\n\tduas   três", "É à í." ])
        , test "leitura é zero sem palavras e arredonda a 200 por minuto" <|
            \_ ->
                Expect.equal [ 0, 1, 2 ] (List.map Domain.readingMinutes [ "", String.repeat 200 "a ", String.repeat 201 "a " ])
        , test "meta limita o indicador a cem por cento" <|
            \_ ->
                case Domain.current Domain.initial of
                    Nothing ->
                        Expect.fail "fixture ausente"

                    Just draft ->
                        Expect.equal [ 0, 50, 100 ] (List.map (\body -> Domain.progress { draft | body = body, goal = 100 }) [ "", String.repeat 50 "a ", String.repeat 150 "a " ])
        , test "editar atualiza somente o texto ativo e a ordem de revisão" <|
            \_ ->
                let
                    old =
                        Domain.initial

                    edited =
                        Domain.editCurrent (\d -> { d | body = "Um novo começo." }) old
                in
                Expect.all [ \_ -> Expect.equal 6 edited.serial, \_ -> Expect.equal (Just "Um novo começo.") (Domain.current edited |> Maybe.map .body), \_ -> Expect.equal (List.drop 1 old.drafts) (List.drop 1 edited.drafts), \_ -> Expect.notEqual old edited ] ()
        , test "novo texto recebe identidade única e preserva o anterior" <|
            \_ ->
                let
                    next =
                        Domain.addDraft "Uma proposta" "O título" Domain.initial
                in
                Expect.all [ \_ -> Expect.equal 6 (List.length next.drafts), \_ -> Expect.equal 6 next.active, \_ -> Expect.equal 7 next.nextId, \_ -> Expect.equal (Just "Uma proposta") (Domain.current next |> Maybe.map .prompt), \_ -> Expect.equal Domain.initial.drafts (List.drop 1 next.drafts) ] ()
        , test "limite de cem textos não adiciona outra entrada" <|
            \_ ->
                let
                    full =
                        List.range 1 95 |> List.foldl (\_ state -> Domain.addDraft "" "" state) Domain.initial
                in
                Expect.equal full (Domain.addDraft "" "Extra" full)
        , test "remover a última entrada deixa o editor vazio de forma válida" <|
            \_ ->
                let
                    empty =
                        List.foldl (\draft state -> Domain.deleteDraft draft.id state) Domain.initial Domain.initial.drafts
                in
                Expect.all [ \_ -> Expect.equal [] empty.drafts, \_ -> Expect.equal Nothing (Domain.current empty), \_ -> Expect.equal (Ok empty) (D.decodeValue Domain.decodeState (Domain.encodeState empty)) ] ()
        , test "busca ignora acentos e respeita os filtros e a ordenação" <|
            \_ ->
                Expect.equal [ 1, 0, 1 ] [ List.length (Domain.filterDrafts "xicara" "todos" "rascunhos" Domain.initial.drafts), List.length (Domain.filterDrafts "xicara" "ficcao" "todos" Domain.initial.drafts), List.length (Domain.filterDrafts "" "todos" "finalizados" Domain.initial.drafts) ]
        , test "backup restaura textos, preferências e seleção sem perda" <|
            \_ ->
                let
                    old =
                        Domain.initial

                    state =
                        { old | night = True, fontSize = 24, active = 3 }
                in
                Expect.equal (Ok state) (D.decodeValue Domain.decodeState (Domain.encodeState state))
        , test "backup rejeita versão desconhecida e JSON quebrado" <|
            \_ ->
                let
                    json =
                        E.encode 0 (Domain.encodeState Domain.initial)
                in
                Expect.all [ \_ -> Expect.err (D.decodeString Domain.decodeState "{"), \_ -> Expect.err (D.decodeString Domain.decodeState (String.replace "\"version\":1" "\"version\":2" json)) ] ()
        , test "backup rejeita identidades repetidas, meta indevida e texto acima do limite" <|
            \_ ->
                case Domain.current Domain.initial of
                    Nothing ->
                        Expect.fail "fixture ausente"

                    Just draft ->
                        let
                            old =
                                Domain.initial
                        in
                        Expect.all (List.map (\drafts -> \_ -> Expect.err (D.decodeValue Domain.decodeState (Domain.encodeState { old | drafts = drafts }))) [ [ draft, draft ], [ { draft | goal = 0 } ], [ { draft | body = String.repeat 80001 "a" } ] ]) ()
        , test "seleção inexistente no backup volta ao primeiro texto" <|
            \_ ->
                let
                    old =
                        Domain.initial
                in
                Expect.equal (Ok 1) (D.decodeValue Domain.decodeState (Domain.encodeState { old | active = 999 }) |> Result.map .active)
        ]
