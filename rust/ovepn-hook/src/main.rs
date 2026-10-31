mod config;
mod net;
mod plan;
use config::Config;
use plan::Plan;
use std::collections::HashMap;
use std::io::{ErrorKind, Write};
use std::process::{Command, ExitCode, Stdio};
use std::{env, fs};
const CONFIG: &str = "/etc/openvpn/ovepn.toml";
const NFT: &str = "/usr/sbin/nft";
const NFT_SET: &str = "ovepn4dst";
// fw4 loads the set from this file on reload
const NFT_SET_FILE: &str = "/var/run/ovepn4dst.txt";
const DNSMASQ_CONF: &str = "/etc/dnsmasq.d/ovepn.conf";
const DNSMASQ_INIT: &str = "/etc/init.d/dnsmasq";
fn main() -> ExitCode {
  let ok = match env::args().nth(1).as_deref() {
    Some("route-up") => route_up(&env::vars().collect()),
    Some("route-pre-down" | "down") => down(),
    _ => true,
  };
  if ok {
    ExitCode::SUCCESS
  } else {
    ExitCode::FAILURE
  }
}
fn route_up(vars: &HashMap<String, String>) -> bool {
  // broken config leaves the set and dnsmasq untouched
  let Some(config) = load_config(CONFIG) else {
    return false;
  };
  let plan = Plan::new(vars, &config);
  for line in &plan.log {
    println!("{line}");
  }
  let nets: Vec<String> = plan.dst.nets().iter().map(ToString::to_string).collect();
  let list: String = nets.iter().flat_map(|n| [n.as_str(), "\n"]).collect();
  let mut ok = write_file(NFT_SET_FILE, &list);
  if load_set(&nets) {
    println!("[{}] added to [{NFT_SET}]", nets.join(" "));
  } else {
    ok = false;
  }
  let conf = plan.dnsmasq_conf();
  if fs::read_to_string(DNSMASQ_CONF).unwrap_or_default() != conf {
    println!("[{DNSMASQ_CONF}] changed:");
    for line in conf.lines() {
      println!("  {line}");
    }
    ok &= write_file(DNSMASQ_CONF, &conf) && restart_dnsmasq();
  }
  ok
}
// missing file means empty config, unreadable or invalid one is an error
fn load_config(path: &str) -> Option<Config> {
  match fs::read_to_string(path) {
    Ok(text) => match config::parse(&text) {
      Ok(config) => Some(config),
      Err(e) => {
        println!("can't parse [{path}]: {e}");
        None
      }
    },
    Err(e) if e.kind() == ErrorKind::NotFound => {
      println!("config [{path}] not found, using empty");
      Some(Config::default())
    }
    Err(e) => {
      println!("can't read [{path}]: {e}");
      None
    }
  }
}
fn down() -> bool {
  let mut ok = load_set(&[]);
  ok &= remove_file(NFT_SET_FILE);
  println!("elements of [{NFT_SET}] removed");
  let filled = fs::metadata(DNSMASQ_CONF).is_ok_and(|m| m.len() > 0);
  ok &= remove_file(DNSMASQ_CONF);
  if filled {
    println!("[{DNSMASQ_CONF}] removed");
    ok &= restart_dnsmasq();
  }
  ok
}
// replace set content in a single transaction
fn load_set(nets: &[String]) -> bool {
  let add = if nets.is_empty() {
    String::new()
  } else {
    format!("add element inet fw4 {NFT_SET} {{ {} }}\n", nets.join(", "))
  };
  let script = format!("flush set inet fw4 {NFT_SET}\n{add}");
  let child = Command::new(NFT)
    .args(["-f", "-"])
    .stdin(Stdio::piped())
    .spawn();
  let result = child.and_then(|mut child| {
    if let Some(mut stdin) = child.stdin.take() {
      stdin.write_all(script.as_bytes())?;
    }
    child.wait()
  });
  match result {
    Ok(status) if status.success() => true,
    Ok(status) => {
      println!("can't load [{NFT_SET}]: [{NFT}] {status}");
      false
    }
    Err(e) => {
      println!("can't load [{NFT_SET}]: [{NFT}] {e}");
      false
    }
  }
}
fn restart_dnsmasq() -> bool {
  match Command::new(DNSMASQ_INIT).arg("restart").status() {
    Ok(status) if status.success() => true,
    Ok(status) => {
      println!("can't restart dnsmasq: {status}");
      false
    }
    Err(e) => {
      println!("can't restart dnsmasq: {e}");
      false
    }
  }
}
// readers never see partially written file
fn write_file(path: &str, content: &str) -> bool {
  let tmp = format!("{path}.tmp");
  match fs::write(&tmp, content).and_then(|()| fs::rename(&tmp, path)) {
    Ok(()) => true,
    Err(e) => {
      println!("can't write [{path}]: {e}");
      false
    }
  }
}
fn remove_file(path: &str) -> bool {
  match fs::remove_file(path) {
    Ok(()) => true,
    Err(e) if e.kind() == ErrorKind::NotFound => true,
    Err(e) => {
      println!("can't remove [{path}]: {e}");
      false
    }
  }
}
#[cfg(test)]
mod tests {
  use super::*;
  use toml::Value;
  #[test]
  fn config_file() {
    let dir = env::temp_dir().join(format!("ovepn-hook-test-{}", std::process::id()));
    // leftovers of an aborted run with the same pid would break the missing file case
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    let path = dir.join("ovepn.toml");
    let file = path.to_str().unwrap();
    // missing file is the empty config
    let config = load_config(file).unwrap();
    assert_eq!(config.nets, []);
    assert!(config.public.is_none());
    assert!(config.domains.is_none());
    fs::write(&path, "public = \"/30\"\n").unwrap();
    assert_eq!(load_config(file).unwrap().public, Some(Value::from("/30")));
    fs::write(&path, "foo = 1\n").unwrap();
    assert!(load_config(file).is_none());
    // a directory exists but can't be read as a file
    assert!(load_config(dir.to_str().unwrap()).is_none());
    fs::remove_dir_all(&dir).unwrap();
  }
}
