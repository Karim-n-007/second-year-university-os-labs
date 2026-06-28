#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
build_dir="$project_dir/build"
classes_dir="$build_dir/classes"
jar_file="$build_dir/process-wather.jar"
java_release="${JAVA_RELEASE:-17}"

rm -rf "$classes_dir"
mkdir -p "$classes_dir"

sources=()
while IFS= read -r -d '' file; do
    sources+=("$file")
done < <(find "$project_dir/src" -type f -name '*.java' -print0 | sort -z)


if [ "${#sources[@]}" -eq 0 ]; then
    echo "No Java sources found."
    exit 1
fi

javac --release "$java_release" -d "$classes_dir" "${sources[@]}"
jar --create --file "$jar_file" --main-class ru.nursafin.processwatcher.ProcessWatcherApp -C "$classes_dir" .

echo "Build completed: $jar_file"
