local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local h = require("colejj.snippets.helpers")

local function uuid()
  return h.uuid()
end

local snippets = {
  s("genid", f(uuid)),
  s("sod_uuid", f(uuid)),
  s("precon", {
    t({ '<preConditions onFail="MARK_RAN">', "  " }),
    i(0),
    t({ "", "</preConditions>" }),
  }),
  s("cs", {
    t('<changeSet id="'),
    f(uuid),
    t({ '" author="tun">', "  " }),
    i(0),
    t({ "", "</changeSet>" }),
  }),
  s("sod_cs", {
    t('<changeSet id="'),
    f(uuid),
    t({ '" author="CHANGE_TO_YOUR_OWN_NAME">', "    ", "</changeSet>" }),
  }),
  s("varchar", { t('<column name="'), i(0), t('" type="varchar(255)"/>') }),
  s("bigint", { t('<column name="'), i(0), t('" type="${bigintType}"/>') }),
  s("datecolumn", { t('<column name="'), i(0), t('" type="${dateType}"/>') }),
  s("varcharMax", { t('<column name="'), i(0), t('" type="clob"/>') }),
  s("nullable", t('<constraints nullable="true"/>')),
  s("notnull", t('<constraints nullable="false"/>')),
  s("droptable", { t('<dropTable tableName="'), i(1), t('"/>') }),
  s("dropCol", { t('<dropColumn tableName="'), i(1), t('" columnName="'), i(2), t('"/>') }),
  s("dropIndex", { t('<dropIndex tableName="'), i(1), t('" indexName="'), i(2), t('"/>') }),
  s("dropFkConstraint", {
    t('<dropForeignKeyConstraint baseTableName="'),
    i(1),
    t('" constraintName="'),
    i(2),
    t('"/>'),
  }),
  s("addcol_string", {
    t('<addColumn tableName="'),
    i(1),
    t({ '">', '    <column name="' }),
    i(2),
    t({ '" type="varchar(255)" />', "</addColumn>" }),
  }),
  s("addcol_bool", {
    t('<addColumn tableName="'),
    i(1),
    t({ '">', '    <column name="' }),
    i(2),
    t({ '" type="${booleanType}" defaultValue="0">', '        <constraints nullable="false"/>', "    </column>", "</addColumn>" }),
  }),
  s("addcol_date", {
    t('<addColumn tableName="'),
    i(1),
    t({ '">', '    <column name="' }),
    i(2),
    t({ '" type="${dateType}" />', "</addColumn>" }),
  }),
  s("addcol_int", {
    t('<addColumn tableName="'),
    i(1),
    t({ '">', '    <column name="' }),
    i(2),
    t({ '" type="${bigintType}">', '        <constraints nullable="false"/>', "    </column>", "</addColumn>" }),
  }),
  s("sod_fk_name", { t("FK_"), f(h.fk_suffix) }),
  s("sod_cs_add_column", {
    t('<changeSet id="'),
    f(uuid),
    t({ '" author="CHANGE_TO_YOUR_OWN_NAME">', '    <preConditions onFail="MARK_RAN">', "      <not>", '        <columnExists tableName="' }),
    i(1),
    t('" columnName="'),
    i(2),
    t({ '"/>', "      </not>", "    </preConditions>", '    <addColumn tableName="' }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ '">', '      <column name="' }),
    f(function(args)
      return args[2][1]
    end, { 2 }),
    t('" type="'),
    i(3),
    t({ '"/>', "    </addColumn>", "</changeSet>" }),
  }),
  s("sod_cs_drop_column", {
    t('<changeSet id="'),
    f(uuid),
    t({ '" author="CHANGE_TO_YOUR_OWN_NAME">', '    <preConditions onFail="MARK_RAN">', '        <columnExists tableName="' }),
    i(1),
    t('" columnName="'),
    i(2),
    t({ '"/>', "    </preConditions>", '    <dropColumn tableName="' }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t('" columnName="'),
    f(function(args)
      return args[2][1]
    end, { 2 }),
    t({ '"/>', "</changeSet>" }),
  }),
}

ls.add_snippets("xml", snippets)
ls.add_snippets("all", {
  s("genid", f(uuid)),
  s("sod_uuid", f(uuid)),
})
