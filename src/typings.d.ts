declare module '*.css' {
  const classNames: {
    [className: string]: string
  };
  export = classNames;
}

declare module 'soundfont-player' {
  const Soundfont: any;

  export default Soundfont;
}

declare module '*.elm' {
  const Elm: any;

  export { Elm }
}