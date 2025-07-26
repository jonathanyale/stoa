use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::Path;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: {} <html_dir> <css_dir>", args[0]);
        process::exit(1);
    }

    let html_dir = &args[1];
    let css_dir = &args[2];

    if !Path::new(html_dir).exists() {
        eprintln!("error: html directory '{}' does not exist", html_dir);
        process::exit(1);
    }

    if !Path::new(css_dir).exists() {
        eprintln!("error: css directory '{}' does not exist", css_dir);
        process::exit(1);
    }

    let html_classes = collect_html_classes(html_dir);
    let css_classes = collect_css_classes(css_dir);

    let html_set: HashSet<&str> = html_classes.iter().map(|s| s.as_str()).collect();
    let css_set: HashSet<&str> = css_classes.iter().map(|s| s.as_str()).collect();

    let html_only: Vec<&str> = html_set.difference(&css_set).cloned().collect();
    let css_only: Vec<&str> = css_set.difference(&html_set).cloned().collect();

    println!(
        "css classes found in html but not in css ({}):",
        html_only.len()
    );
    for class in html_only {
        println!("  {}", class);
    }

    println!(
        "\ncss classes defined in css but not used in html ({}):",
        css_only.len()
    );
    for class in css_only {
        println!("  {}", class);
    }
}

fn collect_html_classes(dir: &str) -> Vec<String> {
    let mut classes = Vec::new();
    collect_files_recursive(Path::new(dir), &mut classes, "html");
    classes
}

fn collect_css_classes(dir: &str) -> Vec<String> {
    let mut classes = Vec::new();
    collect_files_recursive(Path::new(dir), &mut classes, "css");
    classes
}

fn collect_files_recursive(dir: &Path, classes: &mut Vec<String>, ext: &str) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries {
            if let Ok(entry) = entry {
                let path = entry.path();
                if path.is_dir() {
                    collect_files_recursive(&path, classes, ext);
                } else if let Some(file_ext) = path.extension() {
                    if file_ext == ext {
                        if let Ok(content) = fs::read_to_string(&path) {
                            if ext == "html" {
                                classes.extend(extract_html_classes(&content));
                            } else if ext == "css" {
                                classes.extend(extract_css_classes(&content));
                            }
                        }
                    }
                }
            }
        }
    }
}

fn extract_html_classes(content: &str) -> Vec<String> {
    let mut classes = Vec::new();
    let chars: Vec<char> = content.chars().collect();
    let mut i = 0;
    let mut in_tag = false;
    let mut in_class_attr = false;
    let mut class_start = 0;

    while i < chars.len() {
        let c = chars[i];

        if c == '<' {
            in_tag = true;
            in_class_attr = false;
        } else if c == '>' {
            in_tag = false;
            in_class_attr = false;
        } else if in_tag {
            if i + 5 < chars.len()
                && chars[i] == 'c'
                && chars[i + 1] == 'l'
                && chars[i + 2] == 'a'
                && chars[i + 3] == 's'
                && chars[i + 4] == 's'
                && chars[i + 5] == '='
            {
                in_class_attr = true;
                i += 5;
                continue;
            }

            if in_class_attr {
                if c == '"' || c == '\'' {
                    if class_start == 0 {
                        class_start = i + 1;
                    } else {
                        let class_content: String = chars[class_start..i].iter().collect();
                        classes.extend(parse_class_list(&class_content));
                        class_start = 0;
                        in_class_attr = false;
                    }
                }
            }
        }
        i += 1;
    }

    classes
}

fn parse_class_list(class_content: &str) -> Vec<String> {
    class_content
        .split_whitespace()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect()
}

fn extract_css_classes(content: &str) -> Vec<String> {
    let mut classes = Vec::new();
    let lines: Vec<&str> = content.lines().collect();

    for line in lines {
        let trimmed = line.trim();
        if trimmed.ends_with('{') || trimmed.starts_with('.') {
            classes.extend(extract_all_classes_from_line(trimmed));
        }
    }

    classes
}

fn extract_all_classes_from_line(line: &str) -> Vec<String> {
    let mut classes = Vec::new();
    let chars: Vec<char> = line.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        if chars[i] == '.' {
            if let Some(class_name) = extract_class_name_from_pos(&chars, i + 1) {
                classes.push(class_name);
            }
        }
        i += 1;
    }

    classes
}

fn extract_class_name_from_pos(chars: &[char], start: usize) -> Option<String> {
    let mut class_name = String::new();
    let mut i = start;

    while i < chars.len() {
        let c = chars[i];
        if c.is_alphanumeric() || c == '-' || c == '_' {
            class_name.push(c);
        } else {
            break;
        }
        i += 1;
    }

    if !class_name.is_empty() {
        Some(class_name)
    } else {
        None
    }
}
