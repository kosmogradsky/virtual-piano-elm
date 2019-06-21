port module Main exposing (..)

import Bitwise
import Result.Extra
import List exposing (..)
import List.Extra exposing (splitAt)
import State exposing (State(..))

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
    leftShifts = map ((*) leftShiftAByteBy) <| reverse <| range 0 <| length byteArray - 1
    byteArrayWithLeftShifts = map2 Tuple.pair leftShifts byteArray
  in
    foldl (addByteToNumber isVariableLength) 0 byteArrayWithLeftShifts

pop : Int -> State (List a) (List a)
pop n = State (\s -> List.Extra.splitAt n s)

-- parseHeader : List Int -> Result String MidiHeader
-- parseHeader midiBytes =
--   let
--     parsedChunkId = parseStringFromRawChars <| take 4 midiBytes
--     chunkId = if parsedChunkId == "MThd"
--       then Ok parsedChunkId
--       else Err "Header chunk type should be \"MThd\"."

--     parsedSize = parseBytesToNumber False <| take 4 <| drop 4 midiBytes
--     size = if parsedSize == 6
--       then Ok parsedSize
--       else Err <| "Got unexpected header size (" ++ String.fromInt parsedSize ++ "). Header size should be exactly 6 bytes."

--     parsedFormat = parseBytesToNumber False <| take 2 <| drop 8 midiBytes
--     format = if parsedFormat >= 1 && parsedFormat <= 2
--       then Ok parsedFormat
--       else Err <| "Got unknown MIDI file format (" ++ String.fromInt parsedFormat ++ "). The only valid formats are 0, 1 and 2."

--     trackCount = parseBytesToNumber False <| take 2 <| drop 10 midiBytes
--     trackDivision = parseBytesToNumber False <| take 2 <| drop 12 midiBytes
--   in
--     Result.map3 (\_ _ formatInt -> MidiHeader formatInt trackCount trackDivision) chunkId size format

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

buildMidiHeader : Result String String -> Result String Int -> Result String Int -> Int -> Int -> Result String MidiHeader
buildMidiHeader chunkId size format trackCount trackDivision =
  chunkId
    |> Result.andThen (always size)
    |> Result.andThen (always format)
    |> Result.map (MidiHeader trackCount trackDivision)

parseHeader : State (List Int) (Result String MidiHeader)
parseHeader = 
  let
    chunkId = pop 4
      |> State.map parseStringFromRawChars
      |> State.map validateHeaderChunkId

    size = pop 4
      |> State.map (parseBytesToNumber False)
      |> State.map validateHeaderSize

    format = pop 2
      |> State.map (parseBytesToNumber False)
      |> State.map validateMidiFormat
    
    trackCount = pop 2
      |> State.map (parseBytesToNumber False)
    
    trackDivision = pop 2
      |> State.map (parseBytesToNumber False)
  in
    State.map buildMidiHeader chunkId
      |> State.andMap size
      |> State.andMap format
      |> State.andMap trackCount
      |> State.andMap trackDivision

getVlqBytesHelp : List Int -> List Int -> List Int
getVlqBytesHelp vlqBytesSoFar bytes =
  case head bytes of
    Nothing ->
      vlqBytesSoFar
    Just byte ->
      let
        lastVlqOctetMask = 0x7f
      in
        if Bitwise.and lastVlqOctetMask byte == byte
          then byte::vlqBytesSoFar
          else getVlqBytesHelp (byte::vlqBytesSoFar) (drop 1 bytes)


getVariableLengthQuantityBytes : List Int -> List Int
getVariableLengthQuantityBytes bytes = getVlqBytesHelp [] bytes

getValidEventCode : Int -> Result String Int
getValidEventCode code =
  if isSysexEvent code || isMetaEvent code || isChannelEvent code
    then Ok code
    else Err "Got invalid MIDI event code."


type alias ParseEventsState =
  { lastEventCode: Maybe Int
  , eventsSoFar: List MidiEvent
  , midiBytes: List Int
  }

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

-- parseTracksHelp : List Int -> Int -> List MidiTrack -> Result String (List MidiTrack)
-- parseTracksHelp midiBytes trackNumber trackListSoFar =
--   let
--     chunkIdOffset = 4
--     chunkIdBytes = take chunkIdOffset midiBytes
--     parsedChunkId = parseStringFromRawChars chunkIdBytes
--     chunkId = if parsedChunkId == "MTrk"
--       then Ok parsedChunkId
--       else Err "Malformed MIDI: track chunk type should be \"MTrk\"."

--     trackSizeOffset = 4
--     trackSizeBytes = take trackSizeOffset <| drop chunkIdOffset <| midiBytes
--     eventsSize = parseBytesToNumber False trackSizeBytes

--     eventsBytes = take eventsSize <| drop (chunkIdOffset + trackSizeOffset) <| midiBytes
--     -- events = parseEvents trackNumber eventsBytes
--     events = [0]
--   in
--     chunkId |> Result.map (\_ -> [MidiTrack Nothing events])

-- parseTracks : List Int -> Result String (List MidiTrack)
-- parseTracks midiBytes = parseTracksHelp midiBytes 1 []

parse : State (List Int) (Result String Midi)
parse = State.map2 (Result.map2 Midi) parseHeader parseTracks

update : Msg -> () -> ((), Cmd Msg)
update msg model = 
  case msg of
    ParseMidi midiBytes ->
      case State.run midiBytes parse of
        Ok midi ->
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
