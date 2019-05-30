import * as React from 'react';
import * as s from './Keyboard.css';
import cx from 'classnames';
import range from 'ramda/src/range'
import { scaleLinear } from 'd3-scale'

const accidentalPitches = [1, 3, 6, 8, 10]
const isBlackKey = (midiNumber: number) => accidentalPitches.includes(midiNumber % 12)

const colorScale = scaleLinear<string>()
  .domain([0, 127])
  .range(["#05386B", '#379683', '#5CDB95', '8EE4AF', "#EDF5E1"]);

interface Props {
  playNote: (midiNumber: number) => void;
  stopNote: (midiNumber: number) => void;
}

export class Keyboard extends React.PureComponent<Props> {
  render() {
    return (
      <div className={s.keyboard}>
        {range(12 * 1 + 9, 12 * 8 + 1).map(midiNumber => {
          const keyClass = isBlackKey(midiNumber) ? s.blackKey : s.whiteKey;

          // TODO button
          return <div
            key={midiNumber}
            className={cx(s.key, keyClass)}
            onMouseDown={() => this.props.playNote(midiNumber)}
            onMouseUp={() => this.props.stopNote(midiNumber)}
            // style={{
            //   backgroundColor: colorScale(midiNumber)
            // }}
          ></div>
        })}
      </div>
    )
  }
}