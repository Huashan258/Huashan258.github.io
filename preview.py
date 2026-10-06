"""Open the prebuilt site locally. No Ruby or extra Python packages needed."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import webbrowser


def main():
    parser = argparse.ArgumentParser(description="Preview Huashan's optimized blog locally.")
    parser.add_argument("--port", type=int, default=4000)
    parser.add_argument("--no-browser", action="store_true")
    options = parser.parse_args()
    directory = Path(__file__).resolve().parent / "preview"
    if not (directory / "index.html").is_file():
        parser.error("Extract the complete ZIP first; the preview directory is missing.")
    handler = partial(SimpleHTTPRequestHandler, directory=str(directory))
    try:
        server = ThreadingHTTPServer(("127.0.0.1", options.port), handler)
    except OSError as error:
        parser.error(f"Could not open port {options.port}: {error}. Try --port 4001.")
    with server:
        url = f"http://127.0.0.1:{server.server_port}/"
        print("Local preview:", url)
        print("Press Ctrl+C to stop. This does not publish your website.")
        if not options.no_browser:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nPreview stopped.")


if __name__ == "__main__":
    main()
