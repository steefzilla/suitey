use suitey_rust_example::{add, multiply};

#[test]
fn integration_test_add() {
    assert_eq!(add(10, 20), 30);
}

#[test]
fn integration_test_multiply() {
    assert_eq!(multiply(5, 6), 30);
}

#[test]
fn integration_test_combined() {
    let result = add(multiply(2, 3), 4);
    assert_eq!(result, 10);
}
