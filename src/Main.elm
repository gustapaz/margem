port module Main exposing (main)

import Browser
import Browser.Events
import Domain exposing (Draft, State)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode as D
import Json.Encode as E


port persist : E.Value -> Cmd msg


port effects : E.Value -> Cmd msg


port received : (E.Value -> msg) -> Sub msg


type Page
    = Write
    | Index
    | Seeds
    | Journey


type Modal
    = Help
    | Delete Int
    | Import State


type alias Seed =
    { title : String, body : String, category : String }


seeds : List Seed
seeds =
    [ { title = "O que permanece", category = "Observar", body = "Descreva uma coisa pequena que continua no mesmo lugar, apesar de tudo ter mudado." }
    , { title = "Um mapa pelo ouvido", category = "Observar", body = "Feche os olhos por um minuto. Depois, escreva o mapa do lugar em que você está usando apenas os sons." }
    , { title = "A carta que chegou tarde", category = "Imaginar", body = "Uma carta aparece vinte anos depois de ter sido enviada. Comece pela pessoa que abre o envelope." }
    , { title = "Manual do impossível", category = "Imaginar", body = "Escreva um pequeno manual para uma tarefa impossível: guardar o vento, devolver um silêncio ou emprestar uma terça-feira." }
    , { title = "A mesa de antes", category = "Lembrar", body = "Reconstrua uma mesa de uma casa antiga. O que havia sobre ela? Quem costumava sentar ali?" }
    , { title = "O caminho mais longo", category = "Lembrar", body = "Conte sobre um caminho que você fazia sem pressa. Tente lembrar de um detalhe que nunca contou a ninguém." }
    , { title = "A vida de um objeto", category = "Observar", body = "Escolha um objeto ao seu alcance. Conte três histórias diferentes para a marca que ele tem na superfície." }
    , { title = "O último lugar da fila", category = "Imaginar", body = "Duas pessoas esperam por algo que você não vai revelar. Deixe a conversa mostrar o que cada uma teme perder." }
    ]


type alias Model =
    { state : State, page : Page, query : String, notebook : String, status : String, seedCategory : String, seedIndex : Int, focus : Bool, modal : Maybe Modal, notice : String, saveStatus : String, storageError : String, undo : Maybe Draft }


type Msg
    = Navigate Page
    | NewDraft
    | Open Int
    | TitleChanged String
    | BodyChanged String
    | NotebookChanged String
    | GoalChanged String
    | ToggleFinished
    | ToggleFocus
    | ToggleNight
    | FontChanged Int
    | QueryChanged String
    | FilterNotebook String
    | FilterStatus String
    | SeedCategory String
    | ShiftSeed Int
    | UseSeed Seed
    | AskDelete Int
    | ConfirmDelete Int
    | UndoDelete
    | ShowHelp
    | CloseModal
    | Export String
    | ExportBackup
    | ImportBackup
    | ConfirmImport State
    | Bridge E.Value
    | ClearNotice
    | NoOp


main : Program E.Value Model Msg
main =
    Browser.element { init = init, view = view, update = update, subscriptions = subscriptions }


init : E.Value -> ( Model, Cmd Msg )
init flags =
    let
        stored =
            D.decodeValue (D.field "saved" (D.nullable Domain.decodeState)) flags

        initialState =
            case stored of
                Ok (Just value) ->
                    value

                _ ->
                    Domain.initial

        warning =
            case stored of
                Err _ ->
                    "O conteúdo salvo não pôde ser lido. Os exemplos foram abertos; importe um backup válido para recuperar seu caderno."

                _ ->
                    D.decodeValue (D.field "error" D.string) flags |> Result.withDefault ""
    in
    ( { state = initialState
      , page = Write
      , query = ""
      , notebook = "todos"
      , status = "todos"
      , seedCategory = "Todas"
      , seedIndex = 0
      , focus = False
      , modal = Nothing
      , notice = ""
      , saveStatus =
            if warning == "" then
                "Só neste navegador"

            else
                "Atenção ao armazenamento"
      , storageError = warning
      , undo = Nothing
      }
    , Cmd.none
    )


fx : String -> String -> Cmd Msg
fx tag value =
    effects (E.object [ ( "tag", E.string tag ), ( "value", E.string value ) ])


save : State -> Model -> ( Model, Cmd Msg )
save state model =
    ( { model | state = state, saveStatus = "Salvando…" }, persist (Domain.encodeState state) )


edit : (Draft -> Draft) -> Model -> ( Model, Cmd Msg )
edit change model =
    save (Domain.editCurrent change model.state) model


new : String -> String -> Model -> ( Model, Cmd Msg )
new prompt title model =
    if List.length model.state.drafts >= 100 then
        ( { model | notice = "Seu caderno chegou a 100 textos. Exporte e remova algum rascunho para abrir espaço." }, Cmd.none )

    else
        let
            ( next, cmd ) =
                save (Domain.addDraft prompt title model.state) { model | page = Write, focus = False, undo = Nothing }
        in
        ( next, Cmd.batch [ cmd, fx "focus" "draft-title" ] )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Navigate page ->
            ( { model | page = page, focus = False, notice = "" }, fx "page" "main-content" )

        NewDraft ->
            new "" "" model

        UseSeed seed ->
            new seed.body seed.title model

        Open id ->
            let
                old =
                    model.state

                ( next, cmd ) =
                    save { old | active = id } { model | page = Write, focus = False, notice = "" }
            in
            ( next, Cmd.batch [ cmd, fx "page" "main-content" ] )

        TitleChanged title ->
            edit (\d -> { d | title = String.left 120 title }) model

        BodyChanged body ->
            edit (\d -> { d | body = String.left 80000 body }) model

        NotebookChanged value ->
            edit (\d -> { d | notebook = value }) model

        GoalChanged value ->
            edit (\d -> { d | goal = String.toInt value |> Maybe.withDefault 250 }) model

        ToggleFinished ->
            let
                ( next, cmd ) =
                    edit (\d -> { d | finished = not d.finished }) model
            in
            ( { next | notice = "Estado do texto atualizado. Você pode continuar revisando quando quiser." }, cmd )

        ToggleFocus ->
            ( { model | focus = not model.focus }
            , fx "focus"
                (if model.focus then
                    "focus-toggle"

                 else
                    "draft-body"
                )
            )

        ToggleNight ->
            let
                old =
                    model.state
            in
            save { old | night = not old.night } model

        FontChanged value ->
            let
                old =
                    model.state
            in
            save { old | fontSize = clamp 18 24 value } model

        QueryChanged value ->
            ( { model | query = value }, Cmd.none )

        FilterNotebook value ->
            ( { model | notebook = value }, Cmd.none )

        FilterStatus value ->
            ( { model | status = value }, Cmd.none )

        SeedCategory value ->
            ( { model | seedCategory = value, seedIndex = 0 }, Cmd.none )

        ShiftSeed amount ->
            ( { model | seedIndex = modBy (Basics.max 1 (List.length (visibleSeeds model))) (model.seedIndex + amount) }, Cmd.none )

        AskDelete id ->
            ( { model | modal = Just (Delete id) }, fx "dialog" "margem-dialog" )

        ConfirmDelete id ->
            let
                ( next, cmd ) =
                    save (Domain.deleteDraft id model.state) { model | modal = Nothing, undo = List.filter (\d -> d.id == id) model.state.drafts |> List.head, notice = "Texto removido. Você ainda pode desfazer esta remoção." }
            in
            ( next, Cmd.batch [ cmd, fx "restore-focus" "main-content" ] )

        UndoDelete ->
            case model.undo of
                Nothing ->
                    ( model, Cmd.none )

                Just draft ->
                    let
                        old =
                            model.state
                    in
                    save { old | drafts = { draft | updated = old.serial + 1 } :: old.drafts, serial = old.serial + 1 } { model | undo = Nothing, notice = "Texto recuperado." }

        ShowHelp ->
            ( { model | modal = Just Help }, fx "dialog" "margem-dialog" )

        CloseModal ->
            ( { model | modal = Nothing }, fx "restore-focus" "main-content" )

        Export format ->
            case Domain.current model.state of
                Nothing ->
                    ( model, Cmd.none )

                Just draft ->
                    let
                        title =
                            titleOf draft

                        content =
                            if format == "md" then
                                "# " ++ title ++ "\n\n" ++ draft.body ++ "\n"

                            else
                                title ++ "\n\n" ++ draft.body ++ "\n"
                    in
                    ( model, effects (E.object [ ( "tag", E.string "download" ), ( "name", E.string (title ++ "." ++ format) ), ( "content", E.string content ), ( "mime", E.string "text/plain;charset=utf-8" ) ]) )

        ExportBackup ->
            ( model, effects (E.object [ ( "tag", E.string "download" ), ( "name", E.string "margem-backup.json" ), ( "content", E.string (E.encode 2 (Domain.encodeState model.state)) ), ( "mime", E.string "application/json" ) ]) )

        ImportBackup ->
            ( model, fx "import" "" )

        ConfirmImport state ->
            let
                ( next, cmd ) =
                    save state { model | modal = Nothing, undo = Nothing, page = Index, notice = "Backup importado. Seu caderno está pronto para continuar." }
            in
            ( next, Cmd.batch [ cmd, fx "restore-focus" "main-content" ] )

        ClearNotice ->
            ( { model | notice = "", undo = Nothing }, Cmd.none )

        Bridge value ->
            let
                tag =
                    D.decodeValue (D.field "tag" D.string) value |> Result.withDefault ""

                message =
                    D.decodeValue (D.field "message" D.string) value |> Result.withDefault ""
            in
            case tag of
                "saved" ->
                    ( { model | saveStatus = "Salvo neste navegador", storageError = "" }, Cmd.none )

                "error" ->
                    ( { model | storageError = message, saveStatus = "Não foi possível salvar" }, Cmd.none )

                "notice" ->
                    ( { model | notice = message }, Cmd.none )

                "dismiss" ->
                    update CloseModal model

                "imported" ->
                    case D.decodeValue (D.field "data" Domain.decodeState) value of
                        Ok state ->
                            ( { model | modal = Just (Import state) }, fx "dialog" "margem-dialog" )

                        Err _ ->
                            ( { model | notice = "Arquivo inválido. Importe um backup JSON do Margem. Nenhum texto foi alterado." }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ received Bridge
        , if model.focus then
            Browser.Events.onKeyDown
                (D.field "key" D.string
                    |> D.map
                        (\key ->
                            if key == "Escape" then
                                ToggleFocus

                            else
                                NoOp
                        )
                )

          else
            Sub.none
        ]


titleOf : Draft -> String
titleOf draft =
    if String.trim draft.title == "" then
        "Sem título"

    else
        draft.title


visibleSeeds : Model -> List Seed
visibleSeeds model =
    List.filter (\seed -> model.seedCategory == "Todas" || seed.category == model.seedCategory) seeds


activeSeed : Model -> Seed
activeSeed model =
    List.drop model.seedIndex (visibleSeeds model) |> List.head |> Maybe.withDefault { title = "Uma linha", body = "Comece pela coisa mais próxima de você.", category = "Observar" }


attr : String -> String -> Html.Attribute msg
attr =
    attribute


icon : String -> Html msg
icon value =
    span [ class "symbol", attr "aria-hidden" "true" ] [ text value ]


btn : String -> Msg -> List (Html Msg) -> Html Msg
btn style msg children =
    button [ class style, onClick msg, type_ "button" ] children


optionOf : String -> ( String, String ) -> Html Msg
optionOf active ( id, label ) =
    option [ value id, selected (id == active) ] [ text label ]


view : Model -> Html Msg
view model =
    div [ classList [ ( "app", True ), ( "night", model.state.night ), ( "focused", model.focus ) ] ]
        [ a [ class "skip", href "#main-content" ] [ text "Pular para o conteúdo" ]
        , header [ class "masthead" ]
            [ button [ class "wordmark", onClick (Navigate Write), attr "aria-label" "Margem, abrir editor" ] [ text "margem", span [] [ text "." ] ]
            , span [ class "brand-note" ] [ text "UM LUGAR PARA", br [] [], text "AS SUAS PALAVRAS" ]
            , div [ class "masthead-right" ]
                [ span [ class "local-label" ] [ icon "◌", text "sem conta, sem pressa" ]
                , button
                    [ class "icon-button"
                    , onClick ToggleNight
                    , attr "aria-label"
                        (if model.state.night then
                            "Usar tema claro"

                         else
                            "Usar tema noturno"
                        )
                    , attr "aria-pressed"
                        (if model.state.night then
                            "true"

                         else
                            "false"
                        )
                    ]
                    [ text
                        (if model.state.night then
                            "☼"

                         else
                            "☾"
                        )
                    ]
                , button [ class "icon-button help-button", onClick ShowHelp, attr "aria-label" "Como usar o Margem" ] [ text "?" ]
                ]
            ]
        , if model.storageError == "" then
            text ""

          else
            div [ class "storage-error", attr "role" "alert" ] [ text model.storageError, text " Faça um backup para guardar seus textos." ]
        , if model.notice == "" then
            text ""

          else
            div [ class "notice", attr "role" "status" ]
                [ span [] [ text model.notice ]
                , if model.undo /= Nothing then
                    btn "notice-undo" UndoDelete [ text "Desfazer" ]

                  else
                    text ""
                , button [ class "icon-button", onClick ClearNotice, attr "aria-label" "Fechar aviso" ] [ text "×" ]
                ]
        , main_ [ id "main-content", tabindex -1 ]
            [ case model.page of
                Write ->
                    viewEditor model

                Index ->
                    viewIndex model

                Seeds ->
                    viewSeeds model

                Journey ->
                    viewJourney model
            ]
        , nav [ class "dock", attr "aria-label" "Espaços do Margem" ]
            (List.map
                (\( page, label, mark ) ->
                    button
                        [ classList [ ( "dock-item", True ), ( "active", model.page == page ) ]
                        , onClick (Navigate page)
                        , attr "aria-current"
                            (if model.page == page then
                                "page"

                             else
                                "false"
                            )
                        ]
                        [ icon mark, text label ]
                )
                [ ( Write, "Escrever", "✎" ), ( Index, "Índice", "☷" ), ( Seeds, "Sementes", "✳" ), ( Journey, "Percurso", "↗" ) ]
            )
        , footer [ class "site-footer" ] [ span [] [ text "FEITO PARA FICAR ENTRE VOCÊ E A PÁGINA." ], a [ href "https://github.com/gustapaz/margem" ] [ text "Gustavo Paz · código ↗" ] ]
        , viewModal model
        ]


viewEditor : Model -> Html Msg
viewEditor model =
    section [ class "writing-desk" ]
        [ div [ class "desk-toolbar" ]
            [ div [ class "desk-context" ] [ span [ class "eyebrow" ] [ text "SEU CADERNO ABERTO" ], span [ class "save-state", attr "role" "status", attr "aria-live" "polite" ] [ icon "·", text model.saveStatus ] ]
            , div [ class "desk-actions" ]
                [ btn "quiet-button new-draft" NewDraft [ icon "+", text "Novo texto" ]
                , button
                    [ id "focus-toggle"
                    , class "quiet-button"
                    , onClick ToggleFocus
                    , attr "aria-pressed"
                        (if model.focus then
                            "true"

                         else
                            "false"
                        )
                    ]
                    [ icon
                        (if model.focus then
                            "↙"

                         else
                            "↗"
                        )
                    , text
                        (if model.focus then
                            "Sair do foco"

                         else
                            "Modo foco"
                        )
                    ]
                ]
            ]
        , case Domain.current model.state of
            Nothing ->
                div [ class "empty-sheet" ] [ span [ class "big-ornament" ] [ text "✳" ], h1 [] [ text "Toda história começa", br [] [], em [] [ text "com espaço." ] ], p [] [ text "Seu caderno está vazio. Uma linha já é um começo." ], btn "primary" NewDraft [ text "Escrever a primeira linha →" ] ]

            Just draft ->
                article [ class ("folio font-" ++ String.fromInt model.state.fontSize) ]
                    [ div [ class "folio-margin", attr "aria-hidden" "true" ] [ text "DÊ ESPAÇO AO QUE AINDA NÃO SABE DIZER." ]
                    , div [ class "sheet-top" ] [ span [ class "sheet-number" ] [ text ("FOLHA " ++ String.padLeft 3 '0' (String.fromInt draft.id)) ], label [ class "notebook-picker" ] [ span [ class "sr-only" ] [ text "Caderno do texto" ], select [ value draft.notebook, onInput NotebookChanged ] (List.map (optionOf draft.notebook) Domain.notebooks) ] ]
                    , h1 [ class "sr-only" ] [ text "Seu espaço de escrita" ]
                    , label [ class "title-label", for "draft-title" ] [ text "TÍTULO" ]
                    , textarea [ id "draft-title", class "draft-title", value draft.title, onInput TitleChanged, maxlength 120, placeholder "Um título, quando chegar", attr "aria-label" "Título do texto" ] []
                    , if draft.prompt == "" then
                        text ""

                      else
                        details [ class "prompt-note" ] [ summary [] [ text "Uma semente para este texto" ], p [] [ text draft.prompt ] ]
                    , label [ class "sr-only", for "draft-body" ] [ text "Corpo do texto" ]
                    , textarea [ id "draft-body", class "draft-body", value draft.body, onInput BodyChanged, maxlength 80000, placeholder "Comece por qualquer lugar. A primeira linha não precisa ser a definitiva.", attr "spellcheck" "true", attr "aria-describedby" "body-limit" ] []
                    , span [ id "body-limit", class "sr-only" ] [ text "Até 80 mil caracteres por texto. As alterações são salvas apenas neste navegador." ]
                    , div [ class "sheet-bottom" ] [ span [] [ text (String.fromInt (Domain.wordCount draft.body) ++ " palavras") ], span [] [ text (String.fromInt (List.length (String.toList draft.body)) ++ " caracteres") ], span [] [ text (String.fromInt (Domain.readingMinutes draft.body) ++ " min de leitura estimada") ] ]
                    , div [ class "goal-row" ]
                        [ label [] [ text "UM PASSO DE CADA VEZ", select [ value (String.fromInt draft.goal), onInput GoalChanged, attr "aria-label" "Meta de palavras" ] (List.map (\n -> option [ value (String.fromInt n), selected (n == draft.goal) ] [ text (String.fromInt n ++ " palavras") ]) [ 100, 250, 500, 1000, 1500 ]) ]
                        , div [ class "goal-progress" ]
                            [ progress [ Html.Attributes.max "100", value (String.fromInt (Domain.progress draft)), attr "aria-label" "Progresso da meta de palavras" ] []
                            , span []
                                [ text
                                    (if Domain.progress draft >= 100 then
                                        "Meta alcançada. Respire, você chegou."

                                     else
                                        String.fromInt (Domain.progress draft) ++ "% do caminho"
                                    )
                                ]
                            ]
                        ]
                    ]
        , case Domain.current model.state of
            Nothing ->
                text ""

            Just draft ->
                div [ class "editor-foot" ]
                    [ div [ class "type-controls" ] [ span [] [ text "LETRA" ], button [ class "letter-button", onClick (FontChanged (model.state.fontSize - 2)), disabled (model.state.fontSize <= 18), attr "aria-label" "Diminuir letra" ] [ text "A−" ], button [ class "letter-button", onClick (FontChanged (model.state.fontSize + 2)), disabled (model.state.fontSize >= 24), attr "aria-label" "Aumentar letra" ] [ text "A+" ] ]
                    , button
                        [ classList [ ( "finished-toggle", True ), ( "is-finished", draft.finished ) ]
                        , onClick ToggleFinished
                        , attr "aria-pressed"
                            (if draft.finished then
                                "true"

                             else
                                "false"
                            )
                        ]
                        [ icon
                            (if draft.finished then
                                "✓"

                             else
                                "○"
                            )
                        , text
                            (if draft.finished then
                                "Texto finalizado"

                             else
                                "Marcar como finalizado"
                            )
                        ]
                    , div [ class "export-controls" ] [ btn "quiet-button" (Export "txt") [ text ".txt ↓" ], btn "quiet-button" (Export "md") [ text ".md ↓" ] ]
                    ]
        , if model.focus then
            p [ class "focus-note" ] [ text "Só você e a página. Esc para voltar." ]

          else
            p [ class "desk-caption" ] [ text "OS TEXTOS INICIAIS SÃO EXEMPLOS. ESTE ESPAÇO AGORA É SEU." ]
        ]


viewIndex : Model -> Html Msg
viewIndex model =
    let
        drafts =
            Domain.filterDrafts model.query model.notebook model.status model.state.drafts
    in
    section [ class "index-view page-view" ]
        [ div [ class "page-heading" ] [ div [] [ p [ class "eyebrow" ] [ text "O QUE VOCÊ JÁ COLOCOU NO MUNDO" ], h1 [] [ text "Um índice de ", em [] [ text "começos." ] ] ], btn "primary" NewDraft [ text "+ Novo texto" ] ]
        , div [ class "book-tabs", attr "aria-label" "Filtrar por caderno" ]
            (List.map
                (\( key, label ) ->
                    button
                        [ classList [ ( "book-tab", True ), ( "selected", model.notebook == key ) ]
                        , onClick (FilterNotebook key)
                        , attr "aria-pressed"
                            (if model.notebook == key then
                                "true"

                             else
                                "false"
                            )
                        , attr "data-book" key
                        ]
                        [ span [] [ text label ], small [] [ text (String.fromInt (List.length (List.filter (\d -> key == "todos" || d.notebook == key) model.state.drafts))) ] ]
                )
                (( "todos", "Todos os textos" ) :: Domain.notebooks)
            )
        , div [ class "index-filters" ] [ label [] [ span [ class "sr-only" ] [ text "Buscar nos textos" ], input [ type_ "search", placeholder "Uma palavra, um título, uma lembrança…", value model.query, onInput QueryChanged, attr "aria-label" "Buscar nos textos" ] [] ], label [] [ span [ class "sr-only" ] [ text "Estado do texto" ], select [ value model.status, onInput FilterStatus, attr "aria-label" "Estado do texto" ] (List.map (optionOf model.status) [ ( "todos", "Todos os estados" ), ( "rascunhos", "Rascunhos" ), ( "finalizados", "Finalizados" ) ]) ] ]
        , p [ class "results", attr "role" "status" ]
            [ text
                (String.fromInt (List.length drafts)
                    ++ (if List.length drafts == 1 then
                            " texto encontrado"

                        else
                            " textos encontrados"
                       )
                    ++ " · mais recentes primeiro"
                )
            ]
        , if List.isEmpty drafts then
            div [ class "index-empty" ] [ h2 [] [ text "Ainda há espaço por aqui." ], p [] [ text "Não encontramos textos com estes filtros." ], btn "quiet-button" (QueryChanged "") [ text "Limpar busca" ], btn "quiet-button" (FilterNotebook "todos") [ text "Ver todos os cadernos" ], btn "quiet-button" (FilterStatus "todos") [ text "Ver todos os estados" ] ]

          else
            div [ class "entry-list" ] (List.map (viewEntry model) drafts)
        ]


viewEntry : Model -> Draft -> Html Msg
viewEntry model draft =
    article [ class "entry" ]
        [ span [ class "entry-number" ] [ text (String.padLeft 2 '0' (String.fromInt draft.id)) ]
        , button [ class "entry-open", onClick (Open draft.id), attr "aria-label" ("Abrir texto " ++ titleOf draft) ]
            [ div [ class "entry-tags" ]
                [ span [ attr "data-book" draft.notebook ] [ text (Domain.notebookLabel draft.notebook) ]
                , span []
                    [ text
                        (if draft.finished then
                            "✓ finalizado"

                         else
                            "rascunho"
                        )
                    ]
                ]
            , h2 [] [ text (titleOf draft) ]
            , p []
                [ text
                    (if draft.body == "" then
                        "Uma página esperando a primeira linha."

                     else
                        String.left 100 (String.replace "\n" " " draft.body)
                            ++ (if String.length draft.body > 100 then
                                    "…"

                                else
                                    ""
                               )
                    )
                ]
            ]
        , span [ class "entry-words" ] [ text (String.fromInt (Domain.wordCount draft.body)), small [] [ text "PALAVRAS" ] ]
        , button [ class "delete-button", onClick (AskDelete draft.id), attr "aria-label" ("Remover texto " ++ titleOf draft) ] [ text "×" ]
        ]


viewSeeds : Model -> Html Msg
viewSeeds model =
    let
        seed =
            activeSeed model
    in
    section [ class "seeds-view page-view" ]
        [ div [ class "page-heading" ] [ div [] [ p [ class "eyebrow" ] [ text "NENHUMA IDEIA PRECISA NASCER PRONTA" ], h1 [] [ text "Pequenas ", em [] [ text "sementes." ] ] ], span [ class "seed-count" ] [ text (String.fromInt (model.seedIndex + 1) ++ " / " ++ String.fromInt (List.length (visibleSeeds model))) ] ]
        , div [ class "seed-categories", attr "aria-label" "Categorias de propostas" ]
            (List.map
                (\category ->
                    button
                        [ onClick (SeedCategory category)
                        , attr "aria-pressed"
                            (if category == model.seedCategory then
                                "true"

                             else
                                "false"
                            )
                        ]
                        [ text category ]
                )
                [ "Todas", "Observar", "Imaginar", "Lembrar" ]
            )
        , article [ class "seed-card" ] [ div [ class "seed-stamp", attr "aria-hidden" "true" ] [ text "✳" ], p [ class "eyebrow" ] [ text (String.toUpper seed.category ++ " / PROPOSTA DE ESCRITA") ], h2 [] [ text seed.title ], p [ class "seed-body" ] [ text seed.body ], div [ class "seed-card-foot" ] [ span [] [ text "SEM CERTO. SEM ERRADO. SÓ UM COMEÇO." ], btn "primary" (UseSeed seed) [ text "Levar para a página ↗" ] ] ]
        , div [ class "seed-navigation" ] [ btn "quiet-button" (ShiftSeed -1) [ text "← Anterior" ], span [] [ text "Uma proposta por vez." ], btn "quiet-button" (ShiftSeed 1) [ text "Próxima →" ] ]
        , p [ class "seed-note" ] [ text "Cada semente abre um novo rascunho. Nenhum texto seu é substituído." ]
        ]


viewJourney : Model -> Html Msg
viewJourney model =
    let
        total =
            List.sum (List.map (.body >> Domain.wordCount) model.state.drafts)

        finished =
            List.length (List.filter .finished model.state.drafts)
    in
    section [ class "journey-view page-view" ]
        [ div [ class "page-heading" ] [ div [] [ p [ class "eyebrow" ] [ text "NÃO É UMA CORRIDA. É UM PERCURSO." ], h1 [] [ text "Linha por ", em [] [ text "linha." ] ] ] ]
        , div [ class "journey-total" ] [ strong [] [ text (String.fromInt total) ], span [] [ text "palavras que já encontraram um lugar." ] ]
        , div [ class "journey-tallies" ] [ div [] [ strong [] [ text (String.fromInt (List.length model.state.drafts)) ], span [] [ text "textos no caderno" ] ], div [] [ strong [] [ text (String.fromInt finished) ], span [] [ text "textos finalizados" ] ], div [] [ strong [] [ text (String.fromInt (List.length (List.filter (\d -> Domain.progress d >= 100) model.state.drafts))) ], span [] [ text "metas alcançadas" ] ] ]
        , h2 [ class "section-title" ] [ text "As suas palavras, por caderno." ]
        , div [ class "notebook-totals" ]
            (List.map
                (\( key, label ) ->
                    let
                        count =
                            List.sum (List.map (.body >> Domain.wordCount) (List.filter (\d -> d.notebook == key) model.state.drafts))
                    in
                    div [ class "notebook-total", attr "data-book" key ] [ div [] [ span [] [ text label ], strong [] [ text (String.fromInt count ++ " palavras") ] ], progress [ Html.Attributes.max (String.fromInt (Basics.max 1 total)), value (String.fromInt count), attr "aria-label" ("Palavras em " ++ label) ] [] ]
                )
                Domain.notebooks
            )
        , div [ class "backup-area" ] [ div [] [ span [ class "backup-mark", attr "aria-hidden" "true" ] [ text "↙" ], h2 [] [ text "Leve as palavras com você." ], p [] [ text "O caderno fica neste navegador. Baixe um backup para guardar ou continuar em outro dispositivo. Importar substitui os textos atuais, depois da sua confirmação." ] ], div [ class "backup-actions" ] [ btn "primary" ExportBackup [ text "Baixar backup .json ↓" ], btn "quiet-button" ImportBackup [ text "Importar um backup ↗" ] ] ]
        , p [ class "privacy-note" ] [ text "Sem login, nuvem ou envio de conteúdo. As estatísticas incluem os textos de exemplo e refletem apenas o conteúdo atual, sem histórico de atividade." ]
        ]


viewModal : Model -> Html Msg
viewModal model =
    case model.modal of
        Nothing ->
            text ""

        Just modal ->
            node "dialog"
                [ id "margem-dialog", class "margem-dialog", attr "aria-labelledby" "dialog-heading" ]
                [ div [ class "dialog-top" ] [ span [ class "eyebrow" ] [ text "UMA NOTA NA MARGEM" ], button [ class "icon-button", onClick CloseModal, attr "aria-label" "Fechar janela" ] [ text "×" ] ]
                , case modal of
                    Help ->
                        div [] [ h2 [ Html.Attributes.id "dialog-heading" ] [ text "Entre. A página é sua." ], p [] [ text "Margem é um espaço local de escrita. Os cinco textos iniciais e as oito propostas são exemplos autorais; você pode editar, criar e remover à vontade." ], h3 [] [ text "Escreva sem sair do lugar." ], p [] [ text "Título e corpo salvam automaticamente neste navegador. Escolha um caderno, ajuste o tamanho da letra, defina uma meta ou marque o texto como finalizado." ], h3 [] [ text "Só a página, quando precisar." ], p [] [ text "Modo foco esconde a navegação e deixa os controles essenciais. Escape traz tudo de volta. O texto continua editável depois de finalizado." ], h3 [] [ text "Guarde uma cópia." ], p [] [ text "Exporte o texto em TXT ou Markdown. Em Percurso, baixe o backup JSON de todos os textos e importe em outro dispositivo. Limpar os dados do navegador apaga o caderno local." ], p [ class "small-print" ] [ text "Até 100 textos, 120 caracteres no título e 80 mil no corpo de cada texto. A leitura estimada considera 200 palavras por minuto." ], btn "primary" CloseModal [ text "Entendi. Vou escrever." ] ]

                    Delete id ->
                        let
                            draft =
                                List.filter (\d -> d.id == id) model.state.drafts |> List.head
                        in
                        div [] [ h2 [ Html.Attributes.id "dialog-heading" ] [ text "Dar espaço a outro começo?" ], p [] [ text ("Remover “" ++ (Maybe.map titleOf draft |> Maybe.withDefault "este texto") ++ "” do caderno? Você poderá desfazer a remoção no aviso que aparece em seguida.") ], div [ class "dialog-actions" ] [ btn "danger-button" (ConfirmDelete id) [ text "Remover texto" ], btn "quiet-button" CloseModal [ text "Ficar com ele" ] ] ]

                    Import state ->
                        div []
                            [ h2 [ Html.Attributes.id "dialog-heading" ] [ text "Abrir outro caderno?" ]
                            , p []
                                [ text
                                    ("Este backup tem "
                                        ++ String.fromInt (List.length state.drafts)
                                        ++ (if List.length state.drafts == 1 then
                                                " texto"

                                            else
                                                " textos"
                                           )
                                        ++ ". Importar substitui todos os textos e preferências atuais. Baixe uma cópia do seu caderno antes, se quiser preservá-lo."
                                    )
                                ]
                            , div [ class "dialog-actions" ] [ btn "primary" (ConfirmImport state) [ text "Substituir e importar" ], btn "quiet-button" CloseModal [ text "Cancelar" ] ]
                            ]
                ]
