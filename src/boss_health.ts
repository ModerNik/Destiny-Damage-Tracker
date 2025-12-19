// This is a single boss value type
type bossHealthValue = {
  /** Boss name */
  name: string;

  /** Boss health value */
  health: number;

  /** Signals if the boss has final stand mechanic */
  final_stand: boolean;

  /** Name of the activity */
  activity?: string;
};

// This is an array of categories of boss health values
// This object could be used as JSON to convert to CSV.
// It's easier to work with js object then with plain CSV
const bossHealth: {
  /** Category (Group) of bosses */
  category: string;

  /** All bosses of this category */
  values: bossHealthValue[];
}[] = [
  {
    category: "Popular",
    values: [
      {
        name: "Carl",
        health: 1500000,
        final_stand: false,
      },
    ],
  },
  {
    category: "Practice Range",
    values: [
      {
        name: "Carl",
        health: 1500000,
        final_stand: false,
      },
    ],
  },
  {
    category: "Activities",
    values: [
      {
        name: "Savathun",
        health: 249945,
        final_stand: true,
        activity: "TODO: Fill activity name",
      },
    ],
  },
  {
    category: "Dungeons",
    values: [
      {
        name: "Phry'zhia",
        health: 101053,
        final_stand: true,
        activity: "Grasp of Avarice",
      },
    ],
  },
  {
    category: "Raids",
    values: [
      {
        name: "Riven",
        health: 170255,
        final_stand: true,
        activity: "Last Wish",
      },
      {
        name: "Templar",
        health: 182596,
        final_stand: false,
        activity: "Vault of Glass",
      },
      {
        name: "Agraios",
        health: 530451,
        final_stand: false,
        activity: "Desert Perpetual",
      },
    ],
  },
  {
    category: "Additional",
    values: [
      {
        name: "Testing (final)",
        health: 10000000,
        final_stand: false,
      },
      {
        name: "Testing (no final)",
        health: 10000000,
        final_stand: false,
      },
    ],
  },
];
