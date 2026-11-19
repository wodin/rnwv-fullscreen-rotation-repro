import {useEffect, useState} from 'react'
import {
  FlatList,
  type LayoutChangeEvent,
  StatusBar,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native'
import {WebView} from 'react-native-webview'

const ROW_COUNT = 40
const VIDEO_ROW = 20
const ROWS = Array.from({length: ROW_COUNT}, (_, index) => index)

/*
 * The video is a canvas stream, so the page needs no network and no media
 * file. Tapping the stage toggles fullscreen.
 */
const HTML = `
<meta name="viewport" content="width=device-width, initial-scale=1" />
<body style="margin: 0; background: #000; color: #fff; font: 20px sans-serif">
  <div id="stage" style="background: #000">
    <video id="video" muted playsinline style="width: 100%"></video>
    <p id="label" style="text-align: center">Enter fullscreen</p>
  </div>
  <canvas id="canvas" width="320" height="180" hidden></canvas>
  <script>
    const ctx = canvas.getContext('2d')
    let frame = 0
    setInterval(() => {
      ctx.fillStyle = '#036'
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.fillStyle = '#fff'
      ctx.font = '64px sans-serif'
      ctx.fillText(String(frame++), 24, 112)
    }, 100)
    video.srcObject = canvas.captureStream()

    stage.onclick = () => {
      if (document.fullscreenElement) {
        document.exitFullscreen()
      } else {
        video.play()
        stage.requestFullscreen()
      }
    }
    document.onfullscreenchange = () => {
      label.textContent = document.fullscreenElement
        ? 'Exit fullscreen'
        : 'Enter fullscreen'
    }
  </script>
</body>
`

type Counts = {mounts: number; unmounts: number}

export default function App() {
  const {width} = useWindowDimensions()
  const [counts, setCounts] = useState<Counts>({mounts: 0, unmounts: 0})
  const [layouts, setLayouts] = useState<string[]>([])

  const onRootLayout = (e: LayoutChangeEvent) => {
    const {width: w, height: h} = e.nativeEvent.layout
    const size = `${Math.round(w)}x${Math.round(h)}`
    setLayouts(prev => (prev.includes(size) ? prev : [...prev, size]))
  }

  return (
    <View style={styles.root} onLayout={onRootLayout}>
      <View style={styles.counters}>
        <Text>mounts: {counts.mounts}</Text>
        <Text>unmounts: {counts.unmounts}</Text>
        <Text>layouts: {layouts.join(', ')}</Text>
      </View>
      {/*
       * Rows are square, like media in a feed, so they grow with the window
       * width. In landscape that pushes the video row out of the render
       * window, and the list unmounts it.
       */}
      <FlatList
        data={ROWS}
        keyExtractor={String}
        initialScrollIndex={VIDEO_ROW}
        getItemLayout={(_, index) => ({
          length: width,
          offset: width * index,
          index,
        })}
        renderItem={({item}) =>
          item === VIDEO_ROW ? (
            <VideoRow setCounts={setCounts} />
          ) : (
            <View style={styles.row}>
              <Text>Row {item}</Text>
            </View>
          )
        }
      />
    </View>
  )
}

function VideoRow({
  setCounts,
}: {
  setCounts: React.Dispatch<React.SetStateAction<Counts>>
}) {
  useEffect(() => {
    setCounts(c => ({...c, mounts: c.mounts + 1}))
    return () => setCounts(c => ({...c, unmounts: c.unmounts + 1}))
  }, [setCounts])

  return (
    <View style={styles.videoRow}>
      <WebView
        source={{html: HTML}}
        originWhitelist={['*']}
        allowsFullscreenVideo
      />
    </View>
  )
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    paddingTop: StatusBar.currentHeight,
    backgroundColor: '#fff',
  },
  counters: {
    padding: 8,
  },
  row: {
    aspectRatio: 1,
    alignItems: 'center',
    justifyContent: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  videoRow: {
    aspectRatio: 1,
  },
})
