local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local h = require("colejj.snippets.helpers")

local function class_name()
  return h.class_name()
end

local function decap_from_insert(args)
  return h.decap(args[1][1])
end

ls.add_snippets("java", {
  s("logger", {
    t("private static final org.slf4j.Logger LOG = org.slf4j.LoggerFactory.getLogger("),
    f(class_name),
    t(".class);"),
  }),
  s("runmock", t("@RunWith(MockitoJUnitRunner.class)")),
  s("momo", {
    t("private final "),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t(" = Mockito.mock("),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t(".class);"),
    i(0),
  }),
  s("bean", {
    t({ "@Bean", "public " }),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t({ "() {", "  return new " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ "Impl();", "}" }),
    i(0),
  }),
  s("springbean", {
    t({ "@SpringBean", "private " }),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t(";"),
    i(0),
  }),
  s("autowired", {
    t({ "@Autowired", "private " }),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t(";"),
    i(0),
  }),
  s("mock", {
    t({ "@Mock", "private " }),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t(";"),
    i(0),
  }),
  s("sut", {
    t("private "),
    i(1, "Type"),
    t({ " sut;", "", "@Before", "public void setUp() {", "  sut = new " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t("Impl("),
    i(0),
    t({ ");", "}" }),
  }),
  s("sbh", { t('hql.append(" '), i(0), t(' ");') }),
  s("inj", t("InjectorUtils.inject(this);")),
  s("daoconf", {
    t({
      "@Import({EntDbConfig.class, DefaultSodalisBeanConfiguration.class})",
      "public static class ",
    }),
    f(class_name),
    t({
      "Configuration {",
      "",
      "  @Bean",
      "  public ",
    }),
    i(1, "Type"),
    t({ " sut(final SessionFactory sessionFactory) {", "    final " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ "Impl dao = new " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({
      "Impl();",
      "    dao.setSessionFactory(sessionFactory);",
      "    return dao;",
      "  }",
      "  ",
    }),
    i(0),
    t({ "", "}" }),
  }),
  s("concon", {
    t("@ContextConfiguration(classes = "),
    f(class_name),
    t("Configuration.class)"),
  }),
  s("serconf", {
    t({ "@Import(EntDbConfig.class)", "public static class " }),
    f(class_name),
    t({
      "Configuration {",
      "",
      "  @Bean",
      "  public ",
    }),
    i(1, "Type"),
    t({ " sut() {", "    return new " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ "Impl();", "  }", "  " }),
    i(0),
    t({ "", "}" }),
  }),
  s("value", { t('final @Value("${'), i(0), t('}") ') }),
  s("beandao", {
    t({ "@Bean", "public " }),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t({ "(final SessionFactory sessionFactory) {", "  final " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t("Impl dao = new "),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ "Impl();", "  dao.setSessionFactory(sessionFactory);", "  return dao;", "}" }),
  }),
  s("tssolid", {
    t({ "@Override", "public String toString() {", '  return "' }),
    f(class_name),
    t({ ' [id=" + getId() + "]";', "}" }),
  }),
  s("tsshad", {
    t({ "@Override", "public String toString() {", '  return "' }),
    f(class_name),
    t({ ' [id=" + getId() + ", shadowId=" + getShadowId() + "]";', "}" }),
  }),
  s("rules", {
    t({ "@Rule", "public " }),
    i(1, "Type"),
    t(" "),
    f(decap_from_insert, { 1 }),
    t(" = new "),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t("();"),
  }),
  s("poserconf", {
    t({
      "@Import({EntDbConfig.class, DefaultSodalisBeanConfiguration.class})",
      "public static class ",
    }),
    i(1, "Type"),
    t({
      "ImplITConfiguration {",
      "",
      "  @Bean",
      "  public ",
    }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ " sut() {", "    return new " }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ "Impl();", "  }", "  " }),
    i(0),
    t({ "", "}" }),
  }),
  s("std", {
    t({
      "@Test",
      '@TestDefinition(module = ENT, key = CAT + "',
    }),
    i(1),
    t({ '", name = "' }),
    i(2),
    t({
      '",',
      "      author = STH, datacontext = PVM) ",
      '@TestDescription("',
    }),
    i(3),
    t({
      '")',
      '@TestResultExpectation("',
    }),
    i(4),
    t({
      '")',
      '@TestResultCriteria("")',
      "public void std",
    }),
    f(function(args)
      return args[1][1]
    end, { 1 }),
    t({ "() {", "  assureMitarbeiterIsSelected(Mitarbeiter.ZENTRAL);", "  ", "  " }),
    i(0),
    t({ "", "}" }),
  }),
  s("timeTravel", t("@org.junit.Rule public de.guidecom.sodalis.commons.infrastructure.TimeTravel timeTravel = new TimeTravel();")),
  s("funcpriv", { t("private "), i(1, "void"), t(" "), i(2, "name"), t({ "() {", "", "}" }) }),
  s("funcpub", { t("public "), i(1, "void"), t(" "), i(2, "name"), t({ "() {", "", "}" }) }),
  s("if", { t("if ("), i(1), t({ ") {", "    " }), i(0), t({ "", "}" }) }),
  s("else", { t({ "else {", "    " }), i(0), t({ "", "}" }) }),
  s("elseif", { t("else if("), i(1), t({ "){", "  " }), i(0), t({ "", "}" }) }),
  s("ifnull", { t("if ("), i(1, "var"), t({ " == null) {", "  " }), i(0), t({ "", "}" }) }),
  s("ngl", t("!=")),
  s("gl", t("==")),
  s("ngln", t("!= null")),
  s("gln", t("== null")),
  s("tun", t("// tun: ")),
  s("info", t("// info:")),
  s("ref", t("// refactor: ")),
  s("now", t("// now: ")),
})
