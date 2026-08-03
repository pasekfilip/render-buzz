for glsl in ./shaders/*; do

    spv=${glsl//glsl/spv}

    if [[ $glsl -nt $spv ]]; then
        echo "Recompiled $glsl"
        glslc $glsl -o $spv
    fi

done

odin run .
