use std::process::{Command, Stdio};
use std::io::{self, Write, BufReader, BufRead, stdin};

fn run_shell_script() -> io::Result<()> {
    let script_path = "scripts/setup.sh";

    let mut command = Command::new("bash")
        .arg(script_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;


    let stdout = BufReader::new(command.stdout.take().unwrap());
    let stderr = BufReader::new(command.stderr.take().unwrap());

    for line in stdout.lines() {
        println!("{}", line?);
    }

    for line in stderr.lines() {
        eprintln!("{}", line?);
    }

    let status = command.wait()?;

    if !status.success() {
        eprintln!("Ошибка при выполнении скрипта с кодом: {}", status);
    }

    Ok(())
}

fn main() -> io::Result<()> {
    match run_shell_script() {
        Ok(_) => {
            println!("Скрипт успешно выполнен.");
        }
        Err(e) => {
            eprintln!("Ошибка: {}", e);
        }
    }

    Ok(())
}
