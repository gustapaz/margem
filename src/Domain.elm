module Domain exposing (Draft, State, addDraft, current, decodeState, deleteDraft, editCurrent, encodeState, filterDrafts, initial, notebookLabel, notebooks, progress, readingMinutes, wordCount)

import Char
import Json.Decode as D
import Json.Encode as E


type alias Draft =
    { id : Int, title : String, body : String, notebook : String, finished : Bool, goal : Int, prompt : String, updated : Int }


type alias State =
    { drafts : List Draft, active : Int, nextId : Int, serial : Int, fontSize : Int, night : Bool }


notebooks : List ( String, String )
notebooks =
    [ ( "cotidiano", "Cotidiano" ), ( "ficcao", "Ficção" ), ( "ideias", "Ideias soltas" ) ]


notebookLabel : String -> String
notebookLabel key =
    notebooks |> List.filter (\( id, _ ) -> id == key) |> List.head |> Maybe.map Tuple.second |> Maybe.withDefault "Cotidiano"


initial : State
initial =
    { drafts =
        [ { id = 1, title = "Pequenas permanências", notebook = "cotidiano", finished = False, goal = 250, prompt = "Escreva sobre uma coisa pequena que continua no mesmo lugar, apesar de tudo ter mudado.", updated = 5, body = "A xícara azul continuava no alto do armário. Não era a mais bonita, nem a que guardava melhor o café quente. Tinha uma lasca perto da alça, um risco atravessado no fundo e a teimosia silenciosa das coisas que ficam.\n\nQuando troquei os móveis de lugar, levei quase uma tarde para decidir onde colocá-la. A mesa mudou de parede. A estante foi para perto da janela. As plantas ganharam uma prateleira nova. A xícara voltou exatamente para o mesmo ponto.\n\nNa manhã seguinte, alcancei a alça sem olhar. E pensei que talvez a casa não fosse o endereço, o tamanho dos cômodos ou a cor que escolhemos para a sala. Talvez fosse esse pequeno movimento do braço, que sabe aonde ir antes mesmo de a gente acordar por inteiro.\n\nHá coisas que não precisam acompanhar a pressa do mundo. Basta estarem ali quando a mão chega." }
        , { id = 2, title = "A cidade antes das oito", notebook = "cotidiano", finished = True, goal = 100, prompt = "", updated = 4, body = "O primeiro som da rua é uma porta de metal. Depois, a vassoura empurra as folhas para perto do meio-fio. Um ônibus passa quase vazio. Na padaria, a luz já estava acesa quando o céu ainda era cinza.\n\nCaminho sem fones para ouvir essa pequena orquestra que não sabe que está tocando. A cidade, antes das oito, ainda tem intervalos. Cabe uma conversa entre dois carros. Cabe olhar para cima sem esbarrar em ninguém. Cabe o cheiro do pão atravessando a calçada.\n\nÀs vezes, chegar cedo não é ganhar tempo. É encontrar um tempo diferente." }
        , { id = 3, title = "A última cabine", notebook = "ficcao", finished = False, goal = 500, prompt = "Uma pessoa encontra um objeto que não deveria mais existir.", updated = 3, body = "A cabine telefônica apareceu na terça-feira, entre a farmácia e o terreno vazio. Na segunda, havia apenas um muro. Lia tinha certeza porque passava ali todos os dias.\n\nO aparelho era verde, com um fio enrolado e uma plaquinha que dizia: chamadas para ontem, três minutos.\n\nEla procurou uma câmera. Procurou alguém escondido atrás da banca de jornal. Então o telefone tocou." }
        , { id = 4, title = "Coisas que merecem um nome", notebook = "ideias", finished = False, goal = 100, prompt = "", updated = 2, body = "A vontade de ficar mais cinco minutos numa livraria.\n\nO barulho de uma chave que você reconhece antes da porta abrir.\n\nA luz que aparece na parede apenas durante uma semana do ano.\n\nUma conversa que termina, mas continua andando com você." }
        , { id = 5, title = "Uma janela acesa", notebook = "ficcao", finished = False, goal = 250, prompt = "Conte a história de uma janela vista de longe.", updated = 1, body = "Todos os dias, às sete e vinte, a janela do terceiro andar acendia. Não às sete e dezenove. Nunca às sete e vinte e um.\n\nDurante anos, Artur achou que era uma lâmpada com temporizador. Até o dia em que se atrasou e viu alguém esperando por ele." }
        ]
    , active = 1
    , nextId = 6
    , serial = 5
    , fontSize = 20
    , night = False
    }


current : State -> Maybe Draft
current state =
    List.filter (\d -> d.id == state.active) state.drafts |> List.head


wordCount : String -> Int
wordCount body =
    body |> String.words |> List.filter (String.toList >> List.any (\c -> Char.toLower c /= Char.toUpper c || Char.isDigit c)) |> List.length


readingMinutes : String -> Int
readingMinutes body =
    ceiling (toFloat (wordCount body) / 200)


progress : Draft -> Int
progress draft =
    if draft.goal <= 0 then
        0

    else
        min 100 (floor (toFloat (wordCount draft.body) * 100 / toFloat draft.goal))


editCurrent : (Draft -> Draft) -> State -> State
editCurrent change state =
    case current state of
        Nothing ->
            state

        Just _ ->
            { state
                | serial = state.serial + 1
                , drafts =
                    List.map
                        (\d ->
                            if d.id == state.active then
                                let
                                    edited =
                                        change d
                                in
                                { edited | updated = state.serial + 1 }

                            else
                                d
                        )
                        state.drafts
            }


addDraft : String -> String -> State -> State
addDraft prompt title state =
    if List.length state.drafts >= 100 then
        state

    else
        { state | active = state.nextId, nextId = state.nextId + 1, serial = state.serial + 1, drafts = { id = state.nextId, title = title, body = "", notebook = "cotidiano", finished = False, goal = 250, prompt = prompt, updated = state.serial + 1 } :: state.drafts }


deleteDraft : Int -> State -> State
deleteDraft id state =
    let
        remaining =
            List.filter (\d -> d.id /= id) state.drafts
    in
    { state
        | drafts = remaining
        , active =
            if state.active == id then
                List.head remaining |> Maybe.map .id |> Maybe.withDefault 0

            else
                state.active
    }


normalize : String -> String
normalize value =
    List.foldl (\( a, b ) text -> String.replace a b text) (String.toLower value) [ ( "á", "a" ), ( "à", "a" ), ( "â", "a" ), ( "ã", "a" ), ( "é", "e" ), ( "ê", "e" ), ( "í", "i" ), ( "ó", "o" ), ( "ô", "o" ), ( "õ", "o" ), ( "ú", "u" ), ( "ç", "c" ) ]


filterDrafts : String -> String -> String -> List Draft -> List Draft
filterDrafts query notebook status drafts =
    drafts |> List.filter (\d -> (notebook == "todos" || d.notebook == notebook) && (status == "todos" || d.finished == (status == "finalizados")) && String.contains (normalize (String.trim query)) (normalize (d.title ++ " " ++ d.body))) |> List.sortBy (.updated >> negate)


encodeDraft : Draft -> E.Value
encodeDraft d =
    E.object [ ( "id", E.int d.id ), ( "title", E.string d.title ), ( "body", E.string d.body ), ( "notebook", E.string d.notebook ), ( "finished", E.bool d.finished ), ( "goal", E.int d.goal ), ( "prompt", E.string d.prompt ), ( "updated", E.int d.updated ) ]


encodeState : State -> E.Value
encodeState s =
    E.object [ ( "version", E.int 1 ), ( "drafts", E.list encodeDraft s.drafts ), ( "active", E.int s.active ), ( "nextId", E.int s.nextId ), ( "serial", E.int s.serial ), ( "fontSize", E.int s.fontSize ), ( "night", E.bool s.night ) ]


draftDecoder : D.Decoder Draft
draftDecoder =
    D.map8 Draft (D.field "id" D.int) (D.field "title" D.string) (D.field "body" D.string) (D.field "notebook" D.string) (D.field "finished" D.bool) (D.field "goal" D.int) (D.field "prompt" D.string) (D.field "updated" D.int)
        |> D.andThen
            (\d ->
                if d.id > 0 && d.updated >= 0 && String.length d.title <= 120 && String.length d.body <= 80000 && String.length d.prompt <= 500 && List.member d.notebook (List.map Tuple.first notebooks) && List.member d.goal [ 100, 250, 500, 1000, 1500 ] then
                    D.succeed d

                else
                    D.fail "Rascunho inválido"
            )


decodeState : D.Decoder State
decodeState =
    D.map7 (\version drafts active serial font night nextId -> ( version, { drafts = drafts, active = active, nextId = Maybe.withDefault ((List.maximum (List.map .id drafts) |> Maybe.withDefault 0) + 1) nextId, serial = serial, fontSize = font, night = night } )) (D.field "version" D.int) (D.field "drafts" (D.list draftDecoder)) (D.field "active" D.int) (D.field "serial" D.int) (D.field "fontSize" D.int) (D.field "night" D.bool) (D.maybe (D.field "nextId" D.int))
        |> D.andThen
            (\( version, s ) ->
                if
                    version
                        /= 1
                        || List.length s.drafts
                        > 100
                        || s.serial
                        < (List.maximum (List.map .updated s.drafts) |> Maybe.withDefault 0)
                        || s.nextId
                        <= (List.maximum (List.map .id s.drafts) |> Maybe.withDefault 0)
                        || not (List.member s.fontSize [ 18, 20, 22, 24 ])
                        || List.length
                            (List.foldl
                                (\d ids ->
                                    if List.member d.id ids then
                                        ids

                                    else
                                        d.id :: ids
                                )
                                []
                                s.drafts
                            )
                        /= List.length s.drafts
                then
                    D.fail "Arquivo incompatível com Margem"

                else
                    D.succeed
                        { s
                            | active =
                                if List.any (\d -> d.id == s.active) s.drafts then
                                    s.active

                                else
                                    List.head s.drafts |> Maybe.map .id |> Maybe.withDefault 0
                        }
            )
