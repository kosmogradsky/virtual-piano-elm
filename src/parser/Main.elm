port module Main exposing (..)

import Bitwise
import Parser exposing (..)

port parseMidi : (List Int -> msg) -> Sub msg
port midiParsed : Midi -> Cmd msg
port midiParseError : String -> Cmd msg

type Msg = ParseMidi (List Int)

type alias MidiHeader =
  { trackCount: Int
  , trackDivision: Int
  , format: Int
  }

type alias Midi =
  { header: MidiHeader
  , tracks: List MidiTrack
  }

type alias MidiTrack =
  { name: Maybe String
  , events: List Int
  }

type alias MidiEvent = Int

subscriptions : () -> Sub Msg
subscriptions model =
  parseMidi ParseMidi

isSysexEvent code = 0xf0 <= code && code <= 0xf7

isMetaEvent code = code == 0xff

isNoteOnEvent code = 0x90 <= code && code <= 0x9f

isNoteOffEvent code = 0x80 <= code && code <= 0x8f

isNoteEvent code = isNoteOnEvent code ||
  isNoteOffEvent code

isPolyphonicAftertouchEvent code = 0xa0 <= code && code <= 0xaf

isControlChangeEvent code = 0xb0 <= code && code <= 0xbf

isProgramChangeEvent code = 0xc0 <= code && code <= 0xcf

isChannelAftertouchEvent code = 0xd0 <= code && code <= 0xdf

isPitchWheelEvent code = 0xe0 <= code && code <= 0xef

isChannelEvent code = isNoteEvent code || 
  isPolyphonicAftertouchEvent code || 
  isControlChangeEvent code || 
  isProgramChangeEvent code || 
  isChannelAftertouchEvent code || 
  isPitchWheelEvent code

parseStringFromRawChars : List Int -> String
parseStringFromRawChars = String.fromList << map Char.fromCode

addByteToNumber : Bool -> (Int, Int) -> Int -> Int
addByteToNumber isVariableLength (shiftBy, byte) number =
  let
    lastVlqOctetMask = 0x7f
    rawByteValue = if isVariableLength then Bitwise.and byte lastVlqOctetMask else byte
    bitshiftedValue = Bitwise.shiftLeftBy shiftBy rawByteValue
  in
    number + bitshiftedValue

parseBytesToNumber : Bool -> List Int -> Int
parseBytesToNumber isVariableLength byteArray =
  let
    leftShiftAByteBy = if isVariableLength then 7 else 8
    leftShifts = map ((*) leftShiftAByteBy) <| List.reverse <| List.range 0 <| List.length byteArray - 1
    byteArrayWithLeftShifts = map2 Tuple.pair leftShifts byteArray
  in
    List.foldl (addByteToNumber isVariableLength) 0 byteArrayWithLeftShifts

validateHeaderChunkId : String -> Result String String
validateHeaderChunkId chunkId = if chunkId == "MThd"
  then Ok chunkId
  else Err "Header chunk type should be \"MThd\"."

validateHeaderSize : Int -> Result String Int
validateHeaderSize size = if size == 6
  then Ok size
  else Err <| "Got unexpected header size (" ++ String.fromInt size ++ "). Header size should be exactly 6 bytes."

validateMidiFormat : Int -> Result String Int
validateMidiFormat format = if format >= 1 && format <= 2
  then Ok format
  else Err <| "Got unknown MIDI file format (" ++ String.fromInt format ++ "). The only valid formats are 0, 1 and 2."

buildMidiHeader : String -> Int -> Int -> Int -> Int -> MidiHeader
buildMidiHeader chunkId size format trackCount trackDivision =
  MidiHeader trackCount trackDivision

parseHeader : Parser (List Int) MidiHeader
parseHeader = 
  let
    chunkId = pop 4
      |> map parseStringFromRawChars
      |> map validateHeaderChunkId

    size = pop 4
      |> map (parseBytesToNumber False)
      |> map validateHeaderSize

    format = pop 2
      |> map (parseBytesToNumber False)
      |> map validateMidiFormat
    
    trackCount = pop 2
      |> map (parseBytesToNumber False)
    
    trackDivision = pop 2
      |> map (parseBytesToNumber False)
  in
    map buildMidiHeader chunkId
      |> andMap size
      |> andMap format
      |> andMap trackCount
      |> andMap trackDivision

getVlqBytesHelp : List Int -> List Int -> List Int
getVlqBytesHelp vlqBytesSoFar bytes =
  case List.head bytes of
    Nothing ->
      vlqBytesSoFar
    Just byte ->
      let
        lastVlqOctetMask = 0x7f
      in
        if Bitwise.and lastVlqOctetMask byte == byte
          then byte::vlqBytesSoFar
          else getVlqBytesHelp (byte::vlqBytesSoFar) (List.drop 1 bytes)


getVariableLengthQuantityBytes : List Int -> List Int
getVariableLengthQuantityBytes bytes = getVlqBytesHelp [] bytes

getValidEventCode : Int -> Result String Int
getValidEventCode code =
  if isSysexEvent code || isMetaEvent code || isChannelEvent code
    then Ok code
    else Err "Got invalid MIDI event code."

-- parseEventByCode : Int -> Int -> ParseEventsState -> List MidiEvent
-- parseEventByCode trackNumber code state =
--   if isMetaEvent code then

-- parseEventsHelp : Int -> ParseEventsState -> List MidiEvent
-- parseEventsHelp trackNumber state =
--   case state.midiBytes of
--     [] ->
--       state.eventsSoFar
--     _ ->
--       let
--         deltaTimeBytes = getVariableLengthQuantityBytes state.midiBytes
--         deltaTime = parseBytesToNumber True deltaTimeBytes

--         parsedEventCode = drop (length deltaTimeBytes) state.midiBytes
--           |> head
--           |> Result.fromMaybe "MIDI event ended unexpectedly just after delta time and before event code."
--           |> Result.andThen getValidEventCode

--         -- NOTE: if the parsed event code is invalid we assume we have a running status.
--         -- In that case, reuse the last event and process the rest of the
--         -- information as if it were for that type of event.
--         eventCode = Result.Extra.or parsedEventCode state.lastEventCode
--       in
--         Result.andThen (\code -> parseEventByCode trackNumber code { state | midiBytes = drop 1 midiBytes })

-- parseEvents : Int -> List Int -> List MidiEvent
-- parseEvents trackNumber midiBytes =
--   let
--     state =
--       { lastEventCode = Err "Got invalid event code. Attempted to resolve from running status, but there's no previous events."
--       , eventsSoFar = []
--       , midiBytes = midiBytes
--       }
--   in
--     parseEventsHelp trackNumber state

parseUntilEmpty : Parser (List Int) a -> Parser (List Int) (List a)
parseUntilEmpty parseNext = 
  let
    goHelper : List a -> List Int -> Parser (List Int) (Step (List a) (List a))
    goHelper acc midiBytes = 
      case midiBytes of
        [] ->
          return (Done acc)
        _ ->
          parseNext
            |> map (\next -> Loop <| next :: acc)

    go : List a -> Parser (List Int) (Step (List a) (List a))
    go acc = get
      |> andThen (goHelper acc)
  in
    loop [] go

parseNextEvent : Parser (List Int) MidiEvent
parseNextEvent = pop 1
  |> map List.length

parseEvents : Parser (List Int) (List MidiEvent)
parseEvents = parseUntilEmpty parseNextEvent

validateTrackChunkId : String -> Result String String
validateTrackChunkId chunkId = if chunkId == "MTrk"
  then Ok chunkId
  else Err "Malformed MIDI: track chunk type should be \"MTrk\"."

parseNextTrack : Parser (List Int) MidiTrack
parseNextTrack =
  let
    chunkId = pop 4
      |> map parseStringFromRawChars
      |> map validateTrackChunkId

    trackSize = pop 4
      |> map (parseBytesToNumber False)
    
    events = trackSize
      |> andThen pop
      |> map (run parseEvents)
  in
    map2 (\_ evs -> evs) chunkId events
      |> map (MidiTrack Nothing)

parseTracks : Parser (List Int) (List MidiTrack)
parseTracks = parseUntilEmpty parseNextTrack

parse : Parser (List Int) Midi
parse = map2 Midi parseHeader parseTracks

update : Msg -> () -> ((), Cmd Msg)
update msg model = 
  case msg of
    ParseMidi midiBytes ->
      case run parse midiBytes of
        Ok (midi, _) ->
          ((), midiParsed midi)
        Err errorMsg ->
          ((), midiParseError errorMsg)

main : Program () () Msg
main =
  Platform.worker
    { init = \_ -> ((), Cmd.none)
    , update = update
    , subscriptions = subscriptions
    }
