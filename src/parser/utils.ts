export function parseStringFromRawChars(charArray: Uint8Array): string {
	return String.fromCharCode(...charArray);
}

const HIGHBIT_MASK = 0x7f;

export function parseByteArrayToNumber(byteArray: Uint8Array, isVariableLength = false): number {
	const length = byteArray.length;

	return byteArray.reduce((number, oneByte, i) => {
		const rawByteValue = isVariableLength ? oneByte & HIGHBIT_MASK : oneByte;
		const bitshiftedValue = rawByteValue << (length-i-1) * (isVariableLength ? 7 : 8);
		return number + bitshiftedValue;
	}, 0);
}