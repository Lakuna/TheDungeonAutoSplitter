// This script was designed for Pterm version 6.0.4 and is not guaranteed to work on any other version.
state("Pterm", "6.0.4") {
	uint baseAddress : 0x000675D0, 0x2C, 0x4C, 0x04;
	uint offsetAddress : 0x000675D0, 0x2C, 0x4C, 0x0C;
	byte4096 screen : 0x000675D0, 0x2C, 0x4C, 0x04, 0x00;
}

// Runs once on script start-up.
startup {
	// "CORRIDOR"
	byte[] startCondition = { 0xC3, 0xCF, 0xD2, 0xD2, 0xC9, 0x44, 0xCF, 0xD2 };
	vars.startCondition = startCondition;

	// "AUTHOR MODE"
	byte[] resetCondition = { 0x41, 0x55, 0xD4, 0x48, 0xCF, 0xD2, 0xA0, 0x4D, 0xCF, 0x44, 0xC5 };
	vars.resetCondition = resetCondition;

	// "You have conquered the dungeon!"
	byte[] winCondition = { 0x59, 0x6F, 0xF5, 0xA0, 0xE8, 0xE1, 0xF6, 0x65, 0xA0, 0x63, 0x6F, 0xEE, 0x71, 0xF5, 0x65, 0x72, 0x65, 0xE4, 0xA0, 0x74, 0xE8, 0x65, 0xA0, 0xE4, 0xF5, 0x6E, 0xE7, 0x65, 0x6F, 0xEE, 0x21 };
	vars.winCondition = winCondition;
}

// Runs once every update cycle.
update {
	// Skip everything if the screen hasn't loaded yet or if nothing has changed.
	if (current.baseAddress == null || current.offsetAddress == old.offsetAddress) {
		return false;
	}

	/*
	The portion of memory that is being read to determine what is on the screen
	contains 4096 bytes, even though the Pterm screen can contain at most 2048
	characters. Rather than containing a record of what is currently on the
	screen, this memory stores a record of changes in the text on the screen,
	looping back around to the beginning when it runs out of space. We can
	determine if a loop has occurred by checking if the current last modified
	byte is less than the old last modified byte, since it is not possible for
	more than half of the memory to be modified at once.
	*/

	// Determine the beginning and end points of the modified portion.
	ushort firstModifiedIndex = (ushort)((old.offsetAddress ?? 0) - old.baseAddress);
	ushort lastModifiedIndex = (ushort)(current.offsetAddress - current.baseAddress);

	// Determine if a loop occurred.
	bool loopOccurred = lastModifiedIndex < firstModifiedIndex;

	// Determine the size of the modified portion.
	ushort memoryLength = 4096;
	ushort firstSegmentLength = (ushort)(memoryLength - firstModifiedIndex);
	ushort modifiedBytesLength = loopOccurred
		? (ushort)(firstSegmentLength + lastModifiedIndex)
		: (ushort)(lastModifiedIndex - firstModifiedIndex);

	// Create a buffer to store the modified bytes.
	byte[] modifiedBytes = new byte[modifiedBytesLength];

	// Copy the modified bytes into the new buffer.
	if (loopOccurred) {
		Array.Copy(current.screen, firstModifiedIndex, modifiedBytes, 0, firstSegmentLength);
		Array.Copy(current.screen, 0, modifiedBytes, firstSegmentLength, lastModifiedIndex);
	} else {
		Array.Copy(current.screen, firstModifiedIndex, modifiedBytes, 0, modifiedBytesLength);
	}

	// Save the modified bytes for usage in other actions.
	vars.modifiedBytes = modifiedBytes;

	return true; // Skip logging debug information.

	// Convert the modified bytes into a readable string for use in other actions. The ILLIAC II predates UTF-8 by 30 years, so it uses a different encoding.
	StringBuilder builder = new StringBuilder(modifiedBytesLength);
	foreach (byte modifiedByte in modifiedBytes) {
		// Special cases.
		switch (modifiedByte) {
			case 0x60: // Grave in UTF-8, zero in TUTOR.
				builder.Append('0');
				continue;
		}

		// Approximately convert to UTF-8.
		char modifiedChar = modifiedByte < 0x80
			? (char)modifiedByte
			: (char)(modifiedByte - 0x80);

		// Add to string.
		builder.Append(modifiedChar);
	}

	// Log the debug information.
	print("Bytes: " + BitConverter.ToString(modifiedBytes) + "\nString: " + builder.ToString());

	return true;
}

// Runs once every update cycle if the timer has not started. Determines whether the timer should start.
start {
	// Get the start condition.
	byte[] startCondition = vars.startCondition;
	ushort chunkSize = (ushort)startCondition.Length;

	// Check if the modified bytes can possibly contain the start condition.
	byte[] modifiedBytes = vars.modifiedBytes;
	ushort modifiedBytesLength = (ushort)modifiedBytes.Length;
	if (modifiedBytesLength < chunkSize) {
		return false;
	}

	// Create an array to use for comparing portions of the modified bytes against the start condition.
	byte[] bytes = new byte[chunkSize];

	// Check if the modified bytes contain the start condition.
	ushort searchRange = (ushort)(modifiedBytesLength - chunkSize);
	for (ushort i = 0; i < searchRange; i++) {
		Array.Copy(modifiedBytes, i, bytes, 0, chunkSize);
		if (Enumerable.SequenceEqual(bytes, startCondition)) {
			return true;
		}
	}

	return false;
}

// Runs once every update cycle if the timer has started. Determines whether the timer should split.
split {
	// Get the win condition (there is only one split).
	byte[] winCondition = vars.winCondition;
	ushort chunkSize = (ushort)winCondition.Length;

	// Check if the modified bytes can possibly contain the win condition.
	byte[] modifiedBytes = vars.modifiedBytes;
	ushort modifiedBytesLength = (ushort)modifiedBytes.Length;
	if (modifiedBytesLength < chunkSize) {
		return false;
	}

	// Create an array to use for comparing portions of the modified bytes against the win condition.
	byte[] bytes = new byte[chunkSize];

	// Check if the modified bytes contain the win condition.
	ushort searchRange = (ushort)(modifiedBytesLength - chunkSize);
	for (ushort i = 0; i < searchRange; i++) {
		Array.Copy(modifiedBytes, i, bytes, 0, chunkSize);
		if (Enumerable.SequenceEqual(bytes, winCondition)) {
			return true;
		}
	}

	return false;
}

// Runs once every update cycle if the timer has started. Determines whether the timer should reset.
reset {
	// Get the reset condition.
	byte[] resetCondition = vars.resetCondition;
	ushort chunkSize = (ushort)resetCondition.Length;

	// Check if the modified bytes can possibly contain the reset condition.
	byte[] modifiedBytes = vars.modifiedBytes;
	ushort modifiedBytesLength = (ushort)modifiedBytes.Length;
	if (modifiedBytesLength < chunkSize) {
		return false;
	}

	// Create an array to use for comparing portions of the modified bytes against the reset condition.
	byte[] bytes = new byte[chunkSize];

	// Check if the modified bytes contain the reset condition.
	ushort searchRange = (ushort)(modifiedBytesLength - chunkSize);
	for (ushort i = 0; i < searchRange; i++) {
		Array.Copy(modifiedBytes, i, bytes, 0, chunkSize);
		if (Enumerable.SequenceEqual(bytes, resetCondition)) {
			return true;
		}
	}

	return false;
}
