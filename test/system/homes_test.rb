require "application_system_test_case"

class HomesTest < ApplicationSystemTestCase
  setup do
    @home = homes(:one)
  end

  test "visiting the index" do
    visit homes_url
    assert_selector "h1", text: "Notices"
  end

  test "should create notice" do
    visit homes_url
    click_on "New notice"

    click_on "Create Notice"

    assert_text "Notice was successfully created"
    click_on "Back"
  end

  test "should update Home" do
    visit home_url(@home)
    click_on "Edit this notice", match: :first

    click_on "Update Notice"

    assert_text "Notice was successfully updated"
    click_on "Back"
  end

  test "should destroy Home" do
    visit home_url(@home)
    click_on "Destroy this notice", match: :first

    assert_text "Notice was successfully destroyed"
  end
end
