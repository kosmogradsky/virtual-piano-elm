import { Either, Left, Right } from 'fp-ts/es6/Either';
import { parseStringFromRawChars, parseByteArrayToNumber } from "./utils";
import compose from 'ramda/src/compose'

class MidiHeader {
  constructor(
    readonly format: 0 | 1 | 2,
    readonly trackCount: number,
    readonly trackDivision: number
  ) {}
}

class MidiTrack { }

class Midi {
  constructor(
    readonly header: MidiHeader,
    readonly tracks: MidiTrack[]
  ) {}
}

export function isFormatInRange(format: number): format is 0 | 1 | 2 {
  return format < 0 || format > 2
}

export function parseHeader(midiBytes: Uint8Array) {
  const parsedChunkId = parseStringFromRawChars(midiBytes.slice(0, 4));
  const chunkId: Either<string, string> = parsedChunkId === 'MThd'
    ? new Right(parsedChunkId)
    : new Left('Malformed MIDI: header chunk type should be "MThd".')

  const parsedSize = parseByteArrayToNumber(midiBytes.slice(4, 8));
  const size: Either<string, number> = parsedSize === 6
    ? new Right(parsedSize)
    : new Left('Malformed MIDI: got unexpected header size (' + parsedSize + '). Header size should be exactly 6 bytes.')

  const parsedFormat = parseByteArrayToNumber(midiBytes.slice(8, 10));
  const format: Either<string, 0 | 1 | 2> = isFormatInRange(parsedFormat)
    ? new Right(parsedFormat)
    : new Left('Malformed MIDI: got unknown MIDI file format (' + parsedFormat + '). The only valid formats are 0, 1 and 2.')

  const trackCount = parseByteArrayToNumber(midiBytes.slice(10, 12));
	const timeDivision = parseByteArrayToNumber(midiBytes.slice(12, 14));

  return chunkId
    .chain(() => size)
    .chain(() => format)
    .map(format => new MidiHeader(format, trackCount, timeDivision));
}

export function parse(midiBytes: Uint8Array): Result<string, Midi> {
  

  return new Ok(new Midi(new MidiHeader(), [new MidiTrack()]))
}