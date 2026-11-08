pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Artwork is never decoded in the shell as it comes. Album art from media
// players (and images on the shelf) can be anything: a tiny progressive
// JPEG declaring 30000x30000 pixels makes Qt allocate for every coefficient
// whatever sourceSize says, and the whole shell goes with it.
// bin/dynamic-island-art reads the original in its own process, under
// limits, and writes a 256px PNG; only that PNG reaches an Image.
//
//   ArtCache.request(url)          start (once per URL)
//   ArtCache.lookup(url, revision) the safe file:// URL, or "" for none yet
//
// Bounded, since a media player decides how many URLs arrive and how long
// each is (a data: URL can be megabytes): at most maxQueue URLs and
// maxQueueBytes characters wait, the oldest dropped first (the playing
// track's art is always the newest); a URL longer than the helper would
// ever read (maxUrl) is refused before it is queued; results are keyed by
// a short hash, never by the URL itself.
Singleton {
  id: cache

  readonly property string helper: {
    var u = String(Qt.resolvedUrl("../bin/dynamic-island-art"))
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
  }

  // url -> safe URL ("" when the helper refused it). Bumped on every result
  // so bindings that pass it to lookup() re-evaluate.
  property var results: ({})   // key(url) -> safe URL
  property int revision: 0
  property var order: []       // keys, oldest first, to keep the map small
  readonly property int keep: 64

  property var queue: []       // URLs waiting, oldest first
  property int queueBytes: 0
  readonly property int maxQueue: 8
  readonly property int maxQueueBytes: 32 * 1024 * 1024
  // bin/dynamic-island-art reads at most 16 MiB of source; as base64 in a
  // data: URL that is under 22 Mi characters.
  readonly property int maxUrl: 22 * 1024 * 1024
  property string current: ""   // the URL the helper is working on
  property bool busy: false

  function key(url) { return url.length <= 512 ? url : "md5:" + Qt.md5(url) }

  function lookup(url, rev) {
    if (!url) return ""
    var k = key(url)
    return results.hasOwnProperty(k) ? results[k] : ""
  }

  function request(url) {
    if (!url || results.hasOwnProperty(key(url)) || (busy && url === current) || queue.indexOf(url) !== -1) return
    if (url.length > maxUrl) { store(url, ""); return }
    queue.push(url)
    queueBytes += url.length
    while (queue.length > maxQueue || queueBytes > maxQueueBytes) queueBytes -= queue.shift().length
    next()
  }

  function next() {
    if (busy || proc.running || !queue.length) return
    busy = true
    current = queue.shift()
    queueBytes -= current.length
    proc.stdinEnabled = true
    proc.running = true
  }

  function store(url, safe) {
    var k = key(url)
    if (!results.hasOwnProperty(k)) order.push(k)
    results[k] = safe
    while (order.length > keep) delete results[order.shift()]
    revision++
  }

  Process {
    id: proc
    command: [cache.helper]
    // The URL goes over stdin, not as an argument (arguments are visible to
    // other users, and say what is playing).
    onStarted: { write(cache.current + "\n"); stdinEnabled = false }
    stdout: StdioCollector {
      onStreamFinished: {
        var line = text.slice(0, 4096).split("\n")[0]
        cache.store(cache.current, line.indexOf("file:///") === 0 && /\/dynamic-island\/art\/[0-9a-f]{32}\.png$/.test(line) ? line : "")
        cache.current = ""
        cache.busy = false
        Qt.callLater(cache.next)
      }
    }
    onExited: Qt.callLater(cache.next)
  }
}
