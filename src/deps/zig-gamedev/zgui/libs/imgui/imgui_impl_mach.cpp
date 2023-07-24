#include "imgui.h"
#include <math.h>

// Clang warnings with -Weverything
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wold-style-cast"     // warning: use of old-style cast
#pragma clang diagnostic ignored "-Wsign-conversion"    // warning: implicit conversion changes signedness
#if __has_warning("-Wzero-as-null-pointer-constant")
#pragma clang diagnostic ignored "-Wzero-as-null-pointer-constant"
#endif
#endif

extern "C" {
	void ImGui_ImplMach_CursorPosCallback(double x, double y);
	void ImGui_ImplMach_MouseButtonCallback(int button, int action, int mods);
	void ImGui_ImplMach_MouseScrollCallback(double xoffset, double yoffset);
	void ImGui_ImplMach_KeyCallback(int key, int scancode, int action, int mods);
	void ImGui_ImplMach_CharCallback(unsigned int c);
    void ImGui_ImplMach_Init(void);
}

void ImGui_ImplMach_CursorPosCallback(double x, double y) {
    ImGuiIO& io = ImGui::GetIO();
    io.AddMousePosEvent((float)x, (float)y); //TODO: make that dependent on user monitor dpi
}

void ImGui_ImplMach_MouseButtonCallback(int button, int action, int mods) {
    ImGuiIO& io = ImGui::GetIO();
    io.AddMouseButtonEvent(button, action == 1);
}

void ImGui_ImplMach_MouseScrollCallback(double xoffset, double yoffset) {
    ImGuiIO& io = ImGui::GetIO();
    io.AddMouseWheelEvent((float)xoffset, (float)yoffset);
}

void ImGui_ImplMach_KeyCallback(int key, int scancode, int action, int mods) {
	ImGuiIO& io = ImGui::GetIO();
	ImGuiKey imgui_key = static_cast<ImGuiKey>(key);  // todo: make zig key enum => imgui_key conversion
    io.AddKeyEvent(imgui_key, action == 1); // todo: actions fro press and release and repeat
	io.SetKeyEventNativeData(imgui_key, key, scancode);
}


void ImGui_ImplMach_CharCallback(unsigned int c) {
    ImGuiIO& io = ImGui::GetIO();
    io.AddInputCharacter(c);
}

void ImGui_ImplMach_Init() {
    ImGuiIO& io = ImGui::GetIO();
    io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;
}