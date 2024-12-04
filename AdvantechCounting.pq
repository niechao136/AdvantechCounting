// This file contains your Data Connector logic
[Version = "1.0.0"]
section AdvantechCounting;

api_uri = "https://dev-api-apps.wise-apps.com";
pos_uri = "https://dev-pos.wise-apps.com";
access_key = "Eb1mUtnAIS9si8TZ";
form_header = [#"Content-Type" = "application/x-www-form-urlencoded"];
json_header = [#"Content-Type" = "application/json"];

[DataSource.Kind="AdvantechCounting", Publish="AdvantechCounting.Publish"]
shared AdvantechCounting.Navigation = () as table => 
    let
        objects = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "Functions", "Functions", FunctionTable(), "Folder", "Functions", false }
            }
        ),
        navTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;



FunctionTable = () as table => 
    let
        objects = #table(
            { "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf" },
            {
                { "GetSite", "GetSite", AdvantechCounting.GetSite, "Function", "GetSite", true },
                { "GetData", "GetData", AdvantechCounting.GetData, "Function", "GetData", true }
            }
        ),
        navTable = Table.ForceToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable; 


AdvantechCounting.GetSite = Value.ReplaceType(GetSite, GetSiteType);
    GetSiteType = type function (
        acc_id as ( type text meta [
            Documentation.FieldCaption = "Acc ID",
            Documentation.FieldDescription = "Acc ID",
            Documentation.SampleValues = {"Acc ID"}
        ])
    ) as table meta [
        Documentation.Name = "GetSite"
    ];

    GetSite = (acc_id as text) => 
    let
        PostContent = Json.FromValue([ acc_id = acc_id ]),
        res = Json.Document(Web.Contents(api_uri & "/api/store/namelist", [ Headers = form_header, Content = PostContent])),
        site = res[stores] ?? {},
        show = Table.SelectColumns(Table.FromRecords(site), { "store_id", "store_name", "country", "province", "city" })
    in
        show;

AdvantechCounting.GetData = Value.ReplaceType(GetData, GetDataType);
    GetDataType = type function (
        store_id as ( type text meta [
            Documentation.FieldCaption = "Site ID",
            Documentation.FieldDescription = "Site ID",
            Documentation.SampleValues = {"Site ID"}
        ]),
        date_value as (type date meta [
            Documentation.FieldCaption = "Date",
            Documentation.FieldDescription = "Date"
        ]),
        data_range as ( type text meta [
            Documentation.FieldCaption = "Data Range",
            Documentation.FieldDescription = "Data Range",
            Documentation.AllowedValues = {"Day", "Week", "Month", "Year"}
        ])
    ) as table meta [
        Documentation.Name = "GetData"
    ];

    GetData = (store_id as text, date_value as date, data_range as text) => 
    let
        PostContent = Json.FromValue([ store_id = store_id, access_key = access_key ]),
        res = Json.Document(Web.Contents(api_uri & "/api/store/info", [ Headers = form_header, Content = PostContent])),
        site = res[store] ?? [],
        // sensor = List.Select(site[sensors] ?? {}, (o) => Text.Lower(o[device_type] ?? "") = "v-pos" and (o[sensor_id] ?? "") <> ""),
        // sensor_ids = List.Transform(sensor, (o) => o[sensor_id] ?? ""),
        // unit = if data_unit = "Day" then "dd" else "hh",
        // pos = if List.IsEmpty(sensor_ids) then [
        //     account_id = site[acc_id],
        //     rks = { site[register_key] }, 
        //     period = { start_date, end_date },
        //     unit = unit
        // ] else [
        //     account_id = site[acc_id],
        //     rks = { site[register_key] }, 
        //     period = { start_date, end_date },
        //     unit = unit,
        //     sensor_ids = sensor_ids
        // ],
        range = if data_range = "Day" then "dd" else
        (if data_range = "Week" then "ww" else
        (if data_range = "Month" then "mm" else "yyyy")),
        unit = if data_range = "Day" then "hh" else
        (if data_range = "Year" then "mm" else "dd"),
        data_source = [
            analytic = {
                [ caption = "", method = "convert_rate", preprocess_data = { "pin", "crosscnt" } ]
            },
            data_range = range,
            data_unit = unit,
            date = {date_value},
            date_display = "specific",
            date_end = "",
            folding_unit = "",
            is_aggregate = false,
            row_type = "chart",
            source = {
                [
                    caption = "",
                    chart_type = {"line"},
                    merge_type = "sum",
                    monitor_type = "ppc_store_entry",
                    preprocess_data = {"pin"},
                    sources = {
                        [
                            target_id = store_id
                        ]
                    }
                ],
                [
                    caption = "",
                    chart_type = {"line"},
                    merge_type = "sum",
                    monitor_type = "ppc_store_outside",
                    preprocess_data = {"crosscnt"},
                    sources = {
                        [
                            target_id = store_id
                        ]
                    }
                ]
            },
            tags = {},
            time_compare = ""
        ],
        widget_content = [
           data_source = data_source,
           module_id = 0,
           access_key = access_key
        ],
        widget = Json.Document(Web.Contents(api_uri & "/api/widget/data", [ Headers = form_header, Content = Json.FromValue(widget_content)])),
        label = widget[label] ?? {},
        pin = widget[retrived]{0}[data]{0}[pin][row] ?? {},
        crosscnt = widget[retrived]{1}[data]{0}[crosscnt][row] ?? {},
        rate = widget[analytic]{0}[data]{0}[pin][row] ?? {},
        num = {0..(List.Count(label) - 1)},
        data = List.Transform(num, (key) => [
            Label = label{key},
            Traffic = pin{key},
            #"Outside Traffic" = if crosscnt{key} = -99999 then null else crosscnt{key},
            #"Turn in Rate" = if rate{key} = -99999 then null else rate{key}
        ]),
        show = Table.FromRecords(data)
    in
        show;
        

// Data Source Kind description
AdvantechCounting = [
    TestConnection = (dataSourcePath) => {"AdvantechCounting.Navigation"},
    Authentication = [
        // Key = [],
        // UsernamePassword = [
        //     UsernameLabel = Extension.LoadString("Username"),
        //     PasswordLabel = Extension.LoadString("Password"),
        //     Label = Extension.LoadString("AuthenticationLabel")
        // ],
        // Windows = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
AdvantechCounting.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = AdvantechCounting.Icons,
    SourceTypeImage = AdvantechCounting.Icons
];

AdvantechCounting.Icons = [
    Icon16 = { Extension.Contents("AdvantechCounting16.png"), Extension.Contents("AdvantechCounting20.png"), Extension.Contents("AdvantechCounting24.png"), Extension.Contents("AdvantechCounting32.png") },
    Icon32 = { Extension.Contents("AdvantechCounting32.png"), Extension.Contents("AdvantechCounting40.png"), Extension.Contents("AdvantechCounting48.png"), Extension.Contents("AdvantechCounting64.png") }
];

// Common library code
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

Table.ForceToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;
