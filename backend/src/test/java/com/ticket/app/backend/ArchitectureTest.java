package com.ticket.app.backend;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.Dependency;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import org.springframework.stereotype.Repository;
import org.springframework.web.bind.annotation.RestController;

/**
 * The structure rules. Modules: shared, identity, business, buyer, event, booking, admin,
 * demo. Each feature module has the folders controller, dto, service, model and repository
 * (identity and shared also config). Dependencies run {@code identity -> buyer} and
 * {@code booking -> buyer}; buyer uses only shared.
 *
 * <pre>
 *   controller ──► service ──► model ◄── repository
 *   (HTTP)         (use cases,   (entities,  (interfaces,
 *   dto            transactions)  rules)      SQL)
 *   (JSON shapes)
 * </pre>
 *
 * The {@code repository} folder holds the interfaces the services use and, beside them, the SQL
 * classes that implement them: only the interfaces may be used from other layers.
 */
@AnalyzeClasses(packages = "com.ticket.app.backend", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    private static final String ROOT = "com.ticket.app.backend";

    /**
     * The SQL classes: what sits in a repository folder besides the interfaces (and the types nested
     * in those, such as an enum an interface declares).
     */
    private static final DescribedPredicate<JavaClass> SQL_CLASSES =
            DescribedPredicate.describe("SQL classes in a repository folder", ArchitectureTest::isSqlClass);

    @ArchTest
    static final ArchRule theModelIsPlainJava = classes()
            .that().resideInAPackage("..model..")
            .should().onlyDependOnClassesThat().resideInAnyPackage("java..", "..model..")
            .because("business rules must not depend on Spring, SQL or HTTP");

    @ArchTest
    static final ArchRule servicesDoNotKnowAdaptersOrJson = noClasses()
            .that().resideInAPackage("..service..")
            .should().dependOnClassesThat(SQL_CLASSES)
            .orShould().dependOnClassesThat().resideInAnyPackage("..controller..", "..dto..", ROOT + ".identity.config..")
            .because("services talk to storage only through the repository interfaces, and know nothing of HTTP "
                    + "(the settings in shared.config are fine to read)");

    @ArchTest
    static final ArchRule controllersDoNotTouchTheDatabase = noClasses()
            .that().resideInAnyPackage("..controller..", "..dto..", "..config..")
            .should().dependOnClassesThat(SQL_CLASSES)
            .orShould().dependOnClassesThat().resideInAPackage("org.springframework.jdbc..");

    @ArchTest
    static final ArchRule sqlClassesDoNotCallServicesOrControllers = noClasses()
            .that(SQL_CLASSES)
            .should().dependOnClassesThat().resideInAnyPackage("..service..", "..controller..", "..dto..", "..config..");

    @ArchTest
    static final ArchRule controllersLiveInTheControllerFolder = classes()
            .that().areAnnotatedWith(RestController.class)
            .should().resideInAPackage("..controller..");

    @ArchTest
    static final ArchRule repositoriesLiveInTheRepositoryFolder = classes()
            .that().areAnnotatedWith(Repository.class)
            .should().resideInAPackage("..repository..");

    @ArchTest
    static final ArchRule modulesHaveNoCycles = slices()
            .matching(ROOT + ".(*)..")
            .should().beFreeOfCycles();

    @ArchTest
    static final ArchRule sharedKnowsNoFeature = noClasses()
            .that().resideInAPackage(ROOT + ".shared..")
            .should().dependOnClassesThat().resideInAnyPackage(
                    ROOT + ".identity..", ROOT + ".business..", ROOT + ".buyer..", ROOT + ".event..",
                    ROOT + ".booking..", ROOT + ".admin..", ROOT + ".demo..");

    @ArchTest
    static final ArchRule buyersKnowOnlyShared = noClasses()
            .that().resideInAPackage(ROOT + ".buyer..")
            .should().dependOnClassesThat().resideInAnyPackage(
                    ROOT + ".identity..", ROOT + ".business..", ROOT + ".event..", ROOT + ".booking..",
                    ROOT + ".admin..", ROOT + ".demo..")
            .because("a buyer's account is used by identity (sign-in) and booking (bookings by a buyer), not the reverse");

    @ArchTest
    static final ArchRule otherModulesAreUsedThroughTheirModelOrService = classes()
            .should(new ArchCondition<>("use other modules only through their model, service or repository interfaces") {
                @Override
                public void check(JavaClass item, ConditionEvents events) {
                    String own = moduleOf(item);
                    for (Dependency dependency : item.getDirectDependenciesFromSelf()) {
                        JavaClass target = dependency.getTargetClass();
                        String other = moduleOf(target);
                        if (other != null && !other.equals(own) && !other.equals("shared") && isInternal(target)) {
                            events.add(SimpleConditionEvent.violated(dependency, dependency.getDescription()));
                        }
                    }
                }
            });

    /** {@code booking} for {@code com.ticket.app.backend.booking.controller}; null outside the modules. */
    private static String moduleOf(JavaClass javaClass) {
        String packageName = javaClass.getPackageName();
        if (!packageName.startsWith(ROOT + ".")) {
            return null;
        }
        String rest = packageName.substring(ROOT.length() + 1);
        int dot = rest.indexOf('.');
        return dot < 0 ? rest : rest.substring(0, dot);
    }

    /** A top-level class that is not an interface, in a repository folder. */
    private static boolean isSqlClass(JavaClass javaClass) {
        return javaClass.getPackageName().contains(".repository") && !javaClass.isInterface()
                && !javaClass.isNestedClass();
    }

    /** What a module keeps to itself: its controllers, JSON shapes, configuration and SQL classes. */
    private static boolean isInternal(JavaClass javaClass) {
        String packageName = javaClass.getPackageName();
        return packageName.contains(".controller") || packageName.contains(".dto") || packageName.contains(".config")
                || isSqlClass(javaClass);
    }
}
