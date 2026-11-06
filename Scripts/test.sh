#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build/tests
xcrun swiftc -swift-version 5 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/OllamaClient.swift TecWisper/Core/WAV.swift Tests/StubProtocol.swift Tests/CoreTests.swift -o build/tests/CoreTests
build/tests/CoreTests
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/WAV.swift TecWisper/Platform/AudioRecorder.swift Tests/AudioTests.swift -o build/tests/AudioTests
build/tests/AudioTests
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/Statistics.swift TecWisper/Core/DictationHistory.swift TecWisper/Core/StatisticsStore.swift TecWisper/Core/ConnectionCheck.swift TecWisper/StatisticsModel.swift Tests/StatisticsTests.swift -o build/tests/StatisticsTests
build/tests/StatisticsTests
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/OllamaClient.swift TecWisper/Core/ConnectionCheck.swift TecWisper/Core/OllamaConnectionProbe.swift Tests/StubProtocol.swift Tests/ConnectionTests.swift -o build/tests/ConnectionTests
build/tests/ConnectionTests
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/InsertionPolicy.swift Tests/InsertionTests.swift -o build/tests/InsertionTests
build/tests/InsertionTests
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/Statistics.swift TecWisper/Core/DictationHistory.swift TecWisper/Core/StatisticsStore.swift TecWisper/StatisticsModel.swift Tests/HistoryTests.swift -o build/tests/HistoryTests
build/tests/HistoryTests

xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/Statistics.swift TecWisper/Core/DictationHistory.swift TecWisper/Core/StatisticsStore.swift TecWisper/Core/Backup.swift Tests/BackupTests.swift -o build/tests/BackupTests
build/tests/BackupTests
