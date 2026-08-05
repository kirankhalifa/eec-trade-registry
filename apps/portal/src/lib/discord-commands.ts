export const discordCommands = [
  {
    name: "catalogue",
    description: "Search the public East Empire Company catalogue",
    type: 1,
    options: [
      {
        name: "query",
        description: "Item name, code, description, or public tag",
        type: 3,
        required: true,
        max_length: 100,
      },
    ],
  },
  {
    name: "dealer",
    description: "Verify an exact public dealer reference",
    type: 1,
    options: [
      {
        name: "reference",
        description: "Exact public dealer reference",
        type: 3,
        required: true,
        max_length: 128,
      },
    ],
  },
  {
    name: "license",
    description: "Verify an exact public license reference",
    type: 1,
    options: [
      {
        name: "reference",
        description: "Exact public license reference",
        type: 3,
        required: true,
        max_length: 128,
      },
    ],
  },
] as const;
