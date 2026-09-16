#!/usr/bin/env bash
# whites.sh — show how different "white" codes render in your terminal.

RESET='\033[0m'
BGBLACK='\033[40m'   # force a consistent dark background for the samples

print_sample () {
  local label="$1"
  local code="$2"        # e.g. '\033[97m'
  # Show the label, the literal escape sequence, and a colored block
  printf "%-22s %-24s " "$label" "$code"
  # Apply the color on a black background for contrast
  printf "%b%b%s%b\n" "$BGBLACK" "$code" "  █████ WHITE █████  " "$RESET"
}

echo "How your terminal renders different whites (foreground on black bg):"
echo

print_sample "Base white"            '\033[37m'
print_sample "Bold + white"          '\033[1;37m'
print_sample "Bright white (97)"     '\033[97m'
print_sample "256-color white (15)"  '\033[38;5;15m'
print_sample "256-color white (231)" '\033[38;5;231m'
print_sample "Truecolor white"       '\033[38;2;255;255;255m'

echo
echo "Notes:"
echo "• Many terminals render 1;37 (bold white) the same as 97 (bright white)."
echo "• 15 and 231 are both \"white\" in the 256-color palette; some themes map them identically."
echo "• If all lines look the same, your theme likely maps these whites to a single color or ignores truecolor."

