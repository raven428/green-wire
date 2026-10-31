use serde::Deserialize;
use toml::Value;
// /etc/openvpn/ovepn.toml, every key is optional
#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Config {
  // address, address/prefix or address/netmask, always routed into the tunnel;
  // any type here, so a bad element is skipped instead of failing the whole file
  pub nets: Vec<Value>,
  // "none" or "/N" for pushed public networks, missing means "none";
  // any type here, so a bad value falls back to "none"
  pub public: Option<Value>,
  // extra domains resolved by pushed dns servers;
  // any type here, so a bad value or element is skipped instead of failing the whole file
  pub domains: Option<Value>,
}
pub fn parse(text: &str) -> Result<Config, String> {
  toml::from_str(text).map_err(|e| e.to_string())
}
#[cfg(test)]
mod tests {
  use super::*;
  #[test]
  fn full() {
    let config = parse(
      r#"
# networks always routed into the tunnel: address, address/prefix or address/netmask
nets = ["10.20.30.40", "10.20.31.0/24", "10.20.32.0/255.255.255.0"]
# pushed public networks: "none" to ignore all or "/N" to accept up to /N
public = "/30"
# extra domains resolved by pushed dns servers
domains = ["corp.example"]
"#,
    )
    .unwrap();
    assert_eq!(
      config.nets,
      [
        Value::from("10.20.30.40"),
        Value::from("10.20.31.0/24"),
        Value::from("10.20.32.0/255.255.255.0")
      ]
    );
    assert_eq!(config.public, Some(Value::from("/30")));
    assert_eq!(config.domains, Some(Value::from(vec!["corp.example"])));
  }
  #[test]
  fn partial() {
    let config = parse("").unwrap();
    assert_eq!(config.nets, []);
    assert!(config.public.is_none());
    assert!(config.domains.is_none());
    let config = parse("domains = [\"a.example\"]").unwrap();
    assert_eq!(config.nets, []);
    assert!(config.public.is_none());
    assert_eq!(config.domains, Some(Value::from(vec!["a.example"])));
    let config = parse("domains = []").unwrap();
    assert_eq!(config.domains, Some(Value::Array(Vec::new())));
    let config = parse("domains = [1]").unwrap();
    assert_eq!(config.domains, Some(Value::from(vec![1])));
    let config = parse("domains = \"a.example\"").unwrap();
    assert_eq!(config.domains, Some(Value::from("a.example")));
    let config = parse("nets = [\"10.0.0.1\", 42]\npublic = 30").unwrap();
    assert_eq!(config.nets, [Value::from("10.0.0.1"), Value::from(42)]);
    assert_eq!(config.public, Some(Value::from(30)));
  }
  #[test]
  fn errors() {
    for text in [
      "foo = 1",
      "nets = \"10.0.0.1\"",
      "domain = []",
      "domains = [",
      "[nets]",
    ] {
      assert!(parse(text).is_err(), "{text}");
    }
  }
}
