use tokio::io::{self, AsyncBufReadExt, BufReader};
use tokio::net::UnixStream;
use std::path::Path;

const SOCKET_PATH: &str = "/tmp/nfdlog.sock";

#[tokio::main]
async fn main() -> io::Result<()> {
    if !Path::new(SOCKET_PATH).exists() {
        eprintln!("Socket at {} does not exist. Ensure the server is running.", SOCKET_PATH);
        return Ok(());
    }

    let stream = UnixStream::connect(SOCKET_PATH).await?;
    println!("Connected to the Unix socket at {}", SOCKET_PATH);

    // Use this for checking without the buffer
    let mut reader = BufReader::new(stream).lines();

    while let Some(line) = reader.next_line().await? {
        println!("Received log: {}", line);
    }

    println!("Connection closed by server.");
    Ok(())
}
