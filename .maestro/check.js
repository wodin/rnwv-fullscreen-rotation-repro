// Fails with the counters in the message, so the run output shows what it got.
const got = [output.mounts, output.unmounts, output.layouts].join(', ')
if (!new RegExp('^' + WANT + '$').test(got)) {
  throw new Error('Expected "' + WANT + '", got "' + got + '"')
}
