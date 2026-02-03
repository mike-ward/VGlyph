module accessibility

// get_emoji_name returns short name for common emoji (per CONTEXT.md)
// Returns empty string if not an emoji or name unknown
pub fn get_emoji_name(ch rune) string {
	// Common emoji with short names (subset - expandable)
	// Unicode codepoint -> friendly name
	return match ch {
		// Smileys
		0x1F600 { 'grinning face' }
		0x1F601 { 'beaming face' }
		0x1F602 { 'tears of joy' }
		0x1F603 { 'smiling face' }
		0x1F604 { 'grinning squinting face' }
		0x1F605 { 'grinning face with sweat' }
		0x1F606 { 'squinting face' }
		0x1F607 { 'smiling face with halo' }
		0x1F609 { 'winking face' }
		0x1F60A { 'smiling face with smiling eyes' }
		0x1F60B { 'face savoring food' }
		0x1F60C { 'relieved face' }
		0x1F60D { 'heart eyes' }
		0x1F60E { 'sunglasses face' }
		0x1F60F { 'smirking face' }
		0x1F610 { 'neutral face' }
		0x1F611 { 'expressionless face' }
		0x1F612 { 'unamused face' }
		0x1F613 { 'downcast face with sweat' }
		0x1F614 { 'pensive face' }
		0x1F615 { 'confused face' }
		0x1F616 { 'confounded face' }
		0x1F617 { 'kissing face' }
		0x1F618 { 'face blowing kiss' }
		0x1F619 { 'kissing face with smiling eyes' }
		0x1F61A { 'kissing face with closed eyes' }
		0x1F61B { 'face with tongue' }
		0x1F61C { 'winking face with tongue' }
		0x1F61D { 'squinting face with tongue' }
		0x1F61E { 'disappointed face' }
		0x1F61F { 'worried face' }
		0x1F620 { 'angry face' }
		0x1F621 { 'pouting face' }
		0x1F622 { 'crying face' }
		0x1F623 { 'persevering face' }
		0x1F624 { 'face with steam' }
		0x1F625 { 'sad but relieved face' }
		0x1F626 { 'frowning face with open mouth' }
		0x1F627 { 'anguished face' }
		0x1F628 { 'fearful face' }
		0x1F629 { 'weary face' }
		0x1F62A { 'sleepy face' }
		0x1F62B { 'tired face' }
		0x1F62C { 'grimacing face' }
		0x1F62D { 'loudly crying face' }
		0x1F62E { 'face with open mouth' }
		0x1F62F { 'hushed face' }
		0x1F630 { 'anxious face with sweat' }
		0x1F631 { 'face screaming' }
		0x1F632 { 'astonished face' }
		0x1F633 { 'flushed face' }
		0x1F634 { 'sleeping face' }
		0x1F635 { 'dizzy face' }
		0x1F636 { 'face without mouth' }
		0x1F637 { 'face with medical mask' }
		// Gestures
		0x1F44D { 'thumbs up' }
		0x1F44E { 'thumbs down' }
		0x1F44F { 'clapping hands' }
		0x1F64C { 'raising hands' }
		0x1F64F { 'folded hands' }
		0x270B { 'raised hand' }
		0x270C { 'victory hand' }
		0x1F44B { 'waving hand' }
		0x1F44A { 'fist' }
		0x1F91D { 'handshake' }
		// Hearts
		0x2764 { 'red heart' }
		0x1F494 { 'broken heart' }
		0x1F495 { 'two hearts' }
		0x1F496 { 'sparkling heart' }
		0x1F497 { 'growing heart' }
		0x1F498 { 'heart with arrow' }
		0x1F499 { 'blue heart' }
		0x1F49A { 'green heart' }
		0x1F49B { 'yellow heart' }
		0x1F49C { 'purple heart' }
		0x1F5A4 { 'black heart' }
		// Common symbols
		0x2705 { 'check mark' }
		0x274C { 'cross mark' }
		0x2B50 { 'star' }
		0x1F525 { 'fire' }
		0x1F4A1 { 'light bulb' }
		0x1F389 { 'party popper' }
		0x1F680 { 'rocket' }
		0x1F4AF { 'hundred points' }
		0x1F914 { 'thinking face' }
		0x1F923 { 'rolling on floor laughing' }
		else { '' } // Not a known emoji
	}
}
