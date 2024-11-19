use std::io::{self, BufRead};
use std::os::unix::net::UnixListener;
use std::path::Path;
use tokio::io::AsyncWriteExt;
use tokio::net::UnixStream;
use tokio::sync::Mutex;
use std::sync::Arc;

const SOCKET_PATH: &str = "/tmp/nfdlog.sock";

type SharedClients = Arc<Mutex<Vec<UnixStream>>>;

#[tokio::main]
async fn main() -> io::Result<()> {
    // Remove existing socket file if it exists
    if Path::new(SOCKET_PATH).exists() {
        std::fs::remove_file(SOCKET_PATH)?;
    }

    // Shared list to store client connections
    let clients: SharedClients = Arc::new(Mutex::new(Vec::new()));

    // Set up the Unix socket listener
    let listener = UnixListener::bind(SOCKET_PATH)?;
    println!("Unix socket server listening on {}", SOCKET_PATH);

    // Spawn a task to read from stdin and broadcast logs to all connected clients
    let stdin_clients = clients.clone();
    tokio::spawn(async move {
        read_from_stdin(stdin_clients).await;
    });

    // Accept connections asynchronously
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                println!("New client connected");
                let stream = UnixStream::from_std(stream)?;
                let client_list = clients.clone();
                
                // Add the new client to the shared client list
                tokio::spawn(async move {
                    client_list.lock().await.push(stream);
                });
            }
            Err(e) => eprintln!("Error accepting client: {}", e),
        }
    }

    Ok(())
}

async fn read_from_stdin(clients: SharedClients) {
    let stdin = io::stdin();
    let reader = stdin.lock();

    for line in reader.lines() {
        match line {
            Ok(log) => {
                let log_msg = log + "\n";
                // For each log line, send it to all clients
                let clients = clients.clone();
                tokio::spawn(async move {
                    let mut locked_clients = clients.lock().await;
                    let mut disconnected_clients = vec![];

                    for (i, client) in locked_clients.iter_mut().enumerate() {
                        if let Err(_) = client.write_all(log_msg.as_bytes()).await {
                            // If sending fails, mark client as disconnected
                            println!("Client disconnected");
                            disconnected_clients.push(i);
                        }
                    }

                    // Remove disconnected clients
                    for i in disconnected_clients.iter().rev() {
                        locked_clients.remove(*i);
                    }
                });
            }
            Err(e) => eprintln!("Error reading from stdin: {}", e),
        }
        let clients = clients.clone();
        tokio::spawn(async move {
            let mut locked_clients = clients.lock().await;
            let mut disconnected_clients = vec![];

            for (i, client) in locked_clients.iter_mut().enumerate() {
                if let Err(_) = client.flush().await {
                    // If sending fails, mark client as disconnected
                    println!("Client disconnected");
                    disconnected_clients.push(i);
                }
            }

            // Remove disconnected clients
            for i in disconnected_clients.iter().rev() {
                locked_clients.remove(*i);
            }
        });
    }
}