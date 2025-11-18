#!/bin/bash

# Kill any existing shader-bg processes
killall shader-bg 2>/dev/null

# Set environment variable for Poincare Hexagons effect
export SHADER_BG_EFFECT="poincare"

# Launch the application
open ~/Library/Developer/Xcode/DerivedData/shader-bg-*/Build/Products/Debug/shader-bg.app
