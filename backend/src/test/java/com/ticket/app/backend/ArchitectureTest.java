package com.ticket.app.backend;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

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
 * demo. Each feature module has the layers domain, application, infrastructure and web.
 * Dependencies run {@code identity -> buyer} and {@code booking -> buyer}; buyer uses only shared.
 *
 * <pre>
 *   web ──────────► application ──► domain ◄── infrastructure
 *   (controllers,    (use cases,     (entities,     (SQL, SMS)
 *    JSON)            transactions)   rules, ports)
 * </pre>
 */
@AnalyzeClasses(packages = "com.ticket.app.backend", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    private static final String ROOT = "com.ticket.app.backend";

    @ArchTest
    static final ArchRule theDomainIsPlainJava = classes()
            .that().resideInAPackage("..domain..")
            .should().onlyDependOnClassesThat().resideInAnyPackage("java..", "..domain..")
            .because("business rules must not depend on Spring, SQL or HTTP");

    @ArchTest
    static final ArchRule useCasesDoNotKnowAdapters = noClasses()
            .that().resideInAPackage("..application..")
            .should().dependOnClassesThat().resideInAnyPackage("..infrastructure..", "..web..")
            .because("use cases talk to storage only through the domain's repository interfaces");

    @ArchTest
    static final ArchRule controllersDoNotTouchTheDatabase = noClasses()
            .that().resideInAPackage("..web..")
            .should().dependOnClassesThat().resideInAnyPackage("..infrastructure..", "org.springframework.jdbc..");

    @ArchTest
    static final ArchRule adaptersDoNotCallUseCasesOrControllers = noClasses()
            .that().resideInAPackage("..infrastructure..")
            .should().dependOnClassesThat().resideInAnyPackage("..application..", "..web..");

    @ArchTest
    static final ArchRule controllersLiveInWeb = classes()
            .that().areAnnotatedWith(RestController.class)
            .should().resideInAPackage("..web..");

    @ArchTest
    static final ArchRule repositoriesLiveInInfrastructure = classes()
            .that().areAnnotatedWith(Repository.class)
            .should().resideInAPackage("..infrastructure..");

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
    static final ArchRule otherModulesAreUsedThroughTheirDomainOrApplication = classes()
            .should(new ArchCondition<>("use other modules only through their domain or application layer") {
                @Override
                public void check(JavaClass item, ConditionEvents events) {
                    String own = moduleOf(item);
                    for (Dependency dependency : item.getDirectDependenciesFromSelf()) {
                        JavaClass target = dependency.getTargetClass();
                        String other = moduleOf(target);
                        if (other != null && !other.equals(own) && !other.equals("shared") && isAdapter(target)) {
                            events.add(SimpleConditionEvent.violated(dependency, dependency.getDescription()));
                        }
                    }
                }
            });

    /** {@code booking} for {@code com.ticket.app.backend.booking.web}; null outside the modules. */
    private static String moduleOf(JavaClass javaClass) {
        String packageName = javaClass.getPackageName();
        if (!packageName.startsWith(ROOT + ".")) {
            return null;
        }
        String rest = packageName.substring(ROOT.length() + 1);
        int dot = rest.indexOf('.');
        return dot < 0 ? rest : rest.substring(0, dot);
    }

    private static boolean isAdapter(JavaClass javaClass) {
        String packageName = javaClass.getPackageName();
        return packageName.contains(".infrastructure") || packageName.contains(".web");
    }
}
