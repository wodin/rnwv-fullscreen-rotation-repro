/**
 * UNLOCKED=1 builds the variant with no orientation lock. It gets its own
 * package name so both variants can be installed side by side.
 */
module.exports = ({config}) =>
  process.env.UNLOCKED
    ? {
        ...config,
        name: 'RNWV rotation (unlocked)',
        orientation: 'default',
        android: {...config.android, package: `${config.android.package}.unlocked`},
      }
    : config
