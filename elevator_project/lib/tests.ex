defmodule Test do
  def compare_backups() do
    list1 = [1, 2, 3]
    list2 = [2, 3, 4]
    list3 = [4, 5, 6, 7]
    list4 = [2, 4, 5, 8]
    list = [list1, list2, list3, list4]
    OrderDistributor.compare_backups(list)
  end
end