import * as React from 'react'
import { RouteComponentProps } from 'react-router'
import { Keyboard } from '../Keyboard/Keyboard';
import { MidiFileInput } from '../MidiFileInput/MidiFileInput';
import Soundfont from 'soundfont-player';

import './Main.css'

interface State { instrument: any }

export class Main extends React.PureComponent<RouteComponentProps, State> {
  state: State = {
    instrument: null
  }

  playNote = (midiNumber: number) => {
    this.state.instrument.play(midiNumber);
  }

  stopNote = (midiNumber: number) => {
    this.state.instrument.stop(midiNumber);
  }

  componentDidMount() {
    Soundfont.instrument(new AudioContext(), 'acoustic_grand_piano').then((piano: any) => {
      this.setState({ instrument: piano })
    })
  }

  render() {
    // const { lang } = queryString.parse(this.props.location.search)
    // const t = lang === 'en' ? en : ru

    return (
      <>
        <MidiFileInput />
        <Keyboard
          playNote={this.playNote}
          stopNote={this.stopNote}
        />
      </>
    )
  }
}