import * as React from 'react'
import { parserWorker } from '..';

export class MidiFileInput extends React.PureComponent {
  getMidiFile(event: React.ChangeEvent<HTMLInputElement>) {
    const reader = new FileReader();

    if (event.target.files) {
      reader.readAsArrayBuffer(event.target.files[0]);
      
      reader.onloadend = () => {
        if (reader.result instanceof ArrayBuffer) {
          const binaryData = new Uint8Array(reader.result);
          parserWorker.ports.parseMidi.send(Array.from(binaryData))
        } else {
          throw new Error('FileReader result is not an ArrayBuffer')
        }
      }
    }
  }

  render() {
    return <input type='file' onChange={this.getMidiFile} />
  }
}