#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace mbox2::protocol {

struct UsbControlRequest {
    std::uint8_t bmRequestType;
    std::uint8_t bRequest;
    std::uint16_t wValue;
    std::uint16_t wIndex;
    std::uint16_t wLength;
};

// Exact request shape observed in the Mavericks 10.3.9f4 disassembly.
// The Boolean is preserved as an opaque input; its higher-level meaning is
// not assigned here.
constexpr UsbControlRequest makeMavericksFirmwareHandshakeRequest(
    bool flag) noexcept {
    return {0xC0, 0x85, static_cast<std::uint16_t>(flag ? 2 : 1), 0x0001, 0x0001};
}

// Separate Linux boot-status request from sound/usb/quirks.c.
// This is intentionally not merged with the Mavericks one-byte handshake.
constexpr UsbControlRequest makeLinuxBootStatusRequest() noexcept {
    return {0xC0, 0x85, 0x0001, 0x0000, 0x0012};
}

constexpr bool isMavericksFirmwareHandshakeAccepted(
    bool transferSucceeded, std::uint8_t responseByte) noexcept {
    return transferSucceeded && responseByte == 0x01;
}

constexpr std::uint32_t kMavericksHandshakeRetryDelayMilliseconds = 300;
constexpr std::uint32_t kMavericksHandshakeMaximumRetries = 30;
constexpr std::uint32_t kLinuxBootStatusPollIntervalMilliseconds = 500;
constexpr std::uint32_t kLinuxBootStatusMaximumAttempts = 10;
constexpr std::size_t kLinuxBootStatusResponseLength = 18;

enum class LinuxBootStatus {
    malformedResponse,
    loading,
    ready,
    unknownValue,
};

inline LinuxBootStatus parseLinuxBootStatus(const std::uint8_t* bytes,
                                            std::size_t length) noexcept {
    if (bytes == nullptr || length < kLinuxBootStatusResponseLength) {
        return LinuxBootStatus::malformedResponse;
    }
    switch (bytes[0]) {
        case 0x01: return LinuxBootStatus::loading;
        case 0x02: return LinuxBootStatus::ready;
        default: return LinuxBootStatus::unknownValue;
    }
}

// Explicit valid-rate entries found in the Mavericks driver's table.
// These are not a claim about every possible mode/format combination.
constexpr std::array<std::uint32_t, 2> kMavericksValidSampleRates = {
    44100,
    48000,
};

} // namespace mbox2::protocol
