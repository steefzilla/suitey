pub fn add(left: usize, right: usize) -> usize {
    left + right
}

pub fn multiply(x: i32, y: i32) -> i32 {
    x * y
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }

    #[test]
    fn test_multiply() {
        let result = multiply(3, 4);
        assert_eq!(result, 12);
    }

    #[test]
    fn test_multiply_zero() {
        let result = multiply(5, 0);
        assert_eq!(result, 0);
    }
}
