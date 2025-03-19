// Add event listener for keyboard navigation in input fields
document.body.addEventListener('keydown', function(event) {
  // Check if an input element is focused
  if ((document.activeElement.tagName === 'INPUT' && document.activeElement.type === 'text') || document.activeElement.tagName === 'TEXTAREA') {
    const input = document.activeElement;
    const cursorPosition = input.selectionStart;

    // Ctrl+f: Move cursor right
    if (event.ctrlKey && event.key === 'f') {
      event.preventDefault(); // Prevent the default browser action
      if (cursorPosition < input.value.length) {
        input.setSelectionRange(cursorPosition + 1, cursorPosition + 1);
      }
    }

    // Ctrl+b: Move cursor left
    if (event.ctrlKey && event.key === 'b') {
      event.preventDefault(); // Prevent default browser action
      if (cursorPosition > 0) {
        input.setSelectionRange(cursorPosition - 1, cursorPosition - 1);
      }
    }

    // Ctrl+h: Delete character to the left (backspace functionality)
    if (event.ctrlKey && event.key === 'h') {
      event.preventDefault(); // Prevent the default browser action
      if (cursorPosition > 0) {
        // Create new value by removing one character to the left of cursor
        const newValue = input.value.substring(0, cursorPosition - 1) +
                         input.value.substring(cursorPosition);

        // Set the new value and update cursor position
        input.value = newValue;
        input.setSelectionRange(cursorPosition - 1, cursorPosition - 1);
      }
    }

    // Ctrl+d: Delete character at cursor position (delete functionality)
    if (event.ctrlKey && event.key === 'd') {
      event.preventDefault(); // Prevent the default browser action
      if (cursorPosition < input.value.length) {
        // Create new value by removing the character at cursor position
        const newValue = input.value.substring(0, cursorPosition) +
                         input.value.substring(cursorPosition + 1);

        // Set the new value and keep cursor at the same position
        input.value = newValue;
        input.setSelectionRange(cursorPosition, cursorPosition);
      }
    }

    // Ctrl+a: Move cursor to beginning of line
    if (event.ctrlKey && event.key === 'a') {
      event.preventDefault(); // Prevent the default browser action (select all)
      input.setSelectionRange(0, 0);
    }

    // Ctrl+e: Move cursor to end of line
    if (event.ctrlKey && event.key === 'e') {
      event.preventDefault(); // Prevent the default browser action
      input.setSelectionRange(input.value.length, input.value.length);
    }

    // Ctrl+k: Delete from cursor to end of line
    if (event.ctrlKey && event.key === 'k') {
      event.preventDefault(); // Prevent the default browser action
      if (cursorPosition < input.value.length) {
        // Create new value by keeping only text before cursor
        const newValue = input.value.substring(0, cursorPosition);

        // Set the new value and keep cursor at the same position
        input.value = newValue;
        input.setSelectionRange(cursorPosition, cursorPosition);
      }
    }

    // Ctrl+m: Simulate Enter key press
    if (event.ctrlKey && event.key === 'm') {
      event.preventDefault(); // Prevent the default browser action

      // Create and dispatch an Enter key event
      const enterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true,
        cancelable: true
      });

      input.dispatchEvent(enterEvent);
    }
  }
});
