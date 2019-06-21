import * as React from 'react'
import * as ReactDOM from 'react-dom'
import { App } from './App/App';

import { Elm } from './parser/Parser.elm'

export const parserWorker = Elm.Main.init();
parserWorker.ports.midiParsed.subscribe((midiList: any) => {
  console.log(midiList)
})
parserWorker.ports.midiParseError.subscribe((midiList: any) => {
  console.log(midiList)
})

ReactDOM.render(
  <App />,
  document.getElementById('root')
);