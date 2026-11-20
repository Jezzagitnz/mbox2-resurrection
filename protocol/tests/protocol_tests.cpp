#include "mbox2/protocol.hpp"

#include <array>
#include <cassert>
#include <cstdint>

using namespace mbox2::protocol;

int main() {
    const auto mavericksFalse = makeMavericksFirmwareHandshakeRequest(false);
    assert(mavericksFalse.bmRequestType == 0xC0);
    assert(mavericksFalse.bRequest == 0x85);
    assert(mavericksFalse.wValue == 0x0001);
    assert(mavericksFalse.wIndex == 0x0001);
    assert(mavericksFalse.wLength == 0x0001);

    const auto mavericksTrue = makeMavericksFirmwareHandshakeRequest(true);
    assert(mavericksTrue.wValue == 0x0002);
    assert(mavericksTrue.wIndex == 0x0001);
    assert(mavericksTrue.wLength == 0x0001);

    assert(kMavericksHandshakeRetryDelayMilliseconds == 300);
    assert(kMavericksHandshakeMaximumRetries == 30);
    assert(kLinuxBootStatusPollIntervalMilliseconds == 500);
    assert(kLinuxBootStatusMaximumAttempts == 10);

    assert(isMavericksFirmwareHandshakeAccepted(true, 0x01));
    assert(!isMavericksFirmwareHandshakeAccepted(true, 0x00));
    assert(!isMavericksFirmwareHandshakeAccepted(true, 0x02));
    assert(!isMavericksFirmwareHandshakeAccepted(false, 0x01));

    const auto linuxStatus = makeLinuxBootStatusRequest();
    assert(linuxStatus.bmRequestType == 0xC0);
    assert(linuxStatus.bRequest == 0x85);
    assert(linuxStatus.wValue == 0x0001);
    assert(linuxStatus.wIndex == 0x0000);
    assert(linuxStatus.wLength == 0x0012);

    std::array<std::uint8_t, kLinuxBootStatusResponseLength> response{};
    response[0] = 0x01;
    assert(parseLinuxBootStatus(response.data(), response.size()) == LinuxBootStatus::loading);
    response[0] = 0x02;
    assert(parseLinuxBootStatus(response.data(), response.size()) == LinuxBootStatus::ready);
    response[0] = 0x7F;
    assert(parseLinuxBootStatus(response.data(), response.size()) == LinuxBootStatus::unknownValue);
    assert(parseLinuxBootStatus(nullptr, response.size()) == LinuxBootStatus::malformedResponse);
    assert(parseLinuxBootStatus(response.data(), 1) == LinuxBootStatus::malformedResponse);

    assert(kMavericksValidSampleRates[0] == 44100);
    assert(kMavericksValidSampleRates[1] == 48000);

    return 0;
}
